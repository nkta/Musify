import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/API/musify.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/utilities/common_variables.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/utilities/utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clearSearch() {
    _searchBar.clear();
    _songsSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _suggestionsList = [];
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> search() async {
    final query = _searchBar.text;

    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    _fetchingSongs.value = true;

    final youtubeUrlRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final match = youtubeUrlRegex.firstMatch(query);

    if (match != null) {
      final videoId = match.group(1);
      if (videoId != null) {
        try {
          final yt = ProxyManager().getClientSync();
          final video = await yt.videos.get(videoId);
          final song = returnSongLayout(0, video);
          audioHandler.playSong(song);
          _clearSearch();
        } catch (e, stackTrace) {
          logger.log('Error while playing YouTube URL', e, stackTrace);
          if (mounted) {
            showToast(context, context.l10n!.error);
          }
        } finally {
          _fetchingSongs.value = false;
          if (mounted) {
            setState(() {});
          }
        }
        return;
      }
    }

    if (!searchHistory.contains(query)) {
      final updatedHistory = List.from(searchHistory)..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      await addOrUpdateData('user', 'searchHistory', updatedHistory);
    }

    try {
      _songsSearchResult = await fetchSongsList(query);
      _albumsSearchResult = await getPlaylists(query: query, type: 'album');
      _playlistsSearchResult = await getPlaylists(
        query: query,
        type: 'playlist',
      );
    } catch (e, stackTrace) {
      logger.log('Error while searching online songs', e, stackTrace);
    } finally {
      _fetchingSongs.value = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            CustomSearchBar(
              loadingProgressNotifier: _fetchingSongs,
              controller: _searchBar,
              focusNode: _inputNode,
              labelText: '${context.l10n!.search}...',
              onChanged: (value) {
                // debounce suggestions to avoid rapid API calls
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () async {
                  if (value.isNotEmpty) {
                    final s = await getSearchSuggestions(value);
                    _suggestionsList = List<String>.from(s);
                  } else {
                    _suggestionsList = [];
                  }
                  if (mounted) setState(() {});
                });
              },
              onSubmitted: (String value) {
                search();
                _suggestionsList = [];
                _inputNode.unfocus();
              },
            ),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_songsSearchResult.isEmpty && _albumsSearchResult.isEmpty)
                      ? ValueListenableBuilder<List>(
                        valueListenable: searchHistoryNotifier,
                        builder: (context, searchHistory, _) {
                          return ListView.builder(
                            key: ValueKey(
                              'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                            ),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                _suggestionsList.isEmpty
                                    ? searchHistory.length
                                    : _suggestionsList.length,
                            itemBuilder: (BuildContext context, int index) {
                              final suggestionsNotAvailable =
                                  _suggestionsList.isEmpty;
                              final query =
                                  suggestionsNotAvailable
                                      ? searchHistory[index]
                                      : _suggestionsList[index];

                              final borderRadius = getItemBorderRadius(
                                index,
                                _suggestionsList.isEmpty
                                    ? searchHistory.length
                                    : _suggestionsList.length,
                              );

                              return CustomBar(
                                query,
                                FluentIcons.search_24_regular,
                                borderRadius: borderRadius,
                                onTap: () async {
                                  _searchBar.text = query;
                                  await search();
                                  _inputNode.unfocus();
                                },
                                onLongPress: () async {
                                  final confirm =
                                      await _showConfirmationDialog(context) ??
                                      false;
                                  if (confirm) {
                                    final updatedHistory = List.from(
                                      searchHistory,
                                    )..remove(query);
                                    searchHistoryNotifier.value =
                                        updatedHistory;
                                    await addOrUpdateData(
                                      'user',
                                      'searchHistory',
                                      updatedHistory,
                                    );
                                  }
                                },
                              );
                            },
                          );
                        },
                      )
                      : Column(
                        key: ValueKey(
                          'results-${_songsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
                        ),
                        children: [
                          SectionTitle(context.l10n!.songs, primaryColor),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount:
                                _songsSearchResult.length > maxSongsInList
                                    ? maxSongsInList
                                    : _songsSearchResult.length,
                            itemBuilder: (BuildContext context, int index) {
                              final borderRadius = getItemBorderRadius(
                                index,
                                _songsSearchResult.length > maxSongsInList
                                    ? maxSongsInList
                                    : _songsSearchResult.length,
                              );

                              return SongBar(
                                _songsSearchResult[index],
                                true,
                                showMusicDuration: true,
                                borderRadius: borderRadius,
                              );
                            },
                          ),
                          if (_albumsSearchResult.isNotEmpty)
                            SectionTitle(context.l10n!.albums, primaryColor),
                          if (_albumsSearchResult.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  _albumsSearchResult.length > maxSongsInList
                                      ? maxSongsInList
                                      : _albumsSearchResult.length,
                              itemBuilder: (BuildContext context, int index) {
                                final playlist = _albumsSearchResult[index];

                                final borderRadius = getItemBorderRadius(
                                  index,
                                  _albumsSearchResult.length > maxSongsInList
                                      ? maxSongsInList
                                      : _albumsSearchResult.length,
                                );

                                return PlaylistBar(
                                  key: ValueKey(playlist['ytid']),
                                  playlist['title'],
                                  playlistId: playlist['ytid'],
                                  playlistArtwork: playlist['image'],
                                  cubeIcon: FluentIcons.cd_16_filled,
                                  isAlbum: true,
                                  borderRadius: borderRadius,
                                );
                              },
                            ),
                          if (_playlistsSearchResult.isNotEmpty)
                            SectionTitle(context.l10n!.playlists, primaryColor),
                          if (_playlistsSearchResult.isNotEmpty)
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: commonListViewBottmomPadding,
                              itemCount:
                                  _playlistsSearchResult.length > maxSongsInList
                                      ? maxSongsInList
                                      : _playlistsSearchResult.length,
                              itemBuilder: (BuildContext context, int index) {
                                final playlist = _playlistsSearchResult[index];
                                return PlaylistBar(
                                  key: ValueKey(playlist['ytid']),
                                  playlist['title'],
                                  playlistId: playlist['ytid'],
                                  playlistArtwork: playlist['image'],
                                  cubeIcon: FluentIcons.apps_list_24_filled,
                                );
                              },
                            ),
                        ],
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}