/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */
import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/database/radio_stations.db.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/models/radio_model.dart';
import 'package:musify/screens/playlist_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/utilities/sharing_intent.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/radio_station_card.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.query});

  final String? query;

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

enum SearchResultFilter { songs, playlists, lives }

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box('user')
      .get('searchHistory', defaultValue: []);
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  final Set<SearchResultFilter> _activeFilters = {
    SearchResultFilter.songs,
    SearchResultFilter.playlists,
    SearchResultFilter.lives,
  };
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _livesSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<RadioStation> _radioStationsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;
  int _latestSearchRequest = 0;

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    await search();
    _inputNode.unfocus();
  }

  @override
  void initState() {
    super.initState();
    if (widget.query != null) {
      _searchBar.text = widget.query!;
      search();
    }
  }

  @override
  void dispose() {
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clearSearch() {
    _searchBar.clear();
    _songsSearchResult = [];
    _artistsSearchResult = [];
    _livesSearchResult = [];
    _albumsSearchResult = [];
    _playlistsSearchResult = [];
    _radioStationsSearchResult = [];
    _suggestionsList = [];
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> search() async {
    final query = _searchBar.text;
    final requestId = ++_latestSearchRequest;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _livesSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _radioStationsSearchResult = [];
      _suggestionsList = [];
      if (mounted) setState(() {});
      return;
    }
    _fetchingSongs.value = true;

    final youtubeVideoUrlRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|live\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final youtubePlaylistUrlRegex = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?youtube\.com\/playlist\?list=([a-zA-Z0-9_-]+)',
    );

    final videoMatch = youtubeVideoUrlRegex.firstMatch(query);
    if (videoMatch != null) {
      final videoId = videoMatch.group(1);
      if (videoId != null) {
        try {
          final yt = ProxyManager().getClientSync();
          final video = await yt.videos.get(videoId);
          final song = returnSongLayout(0, video);
          Duration? startPosition;
          try {
            final uri = Uri.tryParse(query);
            if (uri != null) {
              final timeParam = uri.queryParameters['t'] ?? uri.queryParameters['start'];
              if (timeParam != null) {
                startPosition = parseYoutubeTimecode(timeParam);
              }
            }
          } catch (_) {}
          await audioHandler.playSong(song, initialPosition: startPosition);
          _clearSearch();
        } catch (e, stackTrace) {
          logger.log('Error while playing YouTube URL', error: e, stackTrace: stackTrace);
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

    final playlistMatch = youtubePlaylistUrlRegex.firstMatch(query);
    if (playlistMatch != null) {
      final playlistId = playlistMatch.group(1);
      if (playlistId != null) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistPage(playlistId: playlistId),
            ),
          ),
        );
        _clearSearch();
        _fetchingSongs.value = false;
        return;
      }
    }

    if (!searchHistory.contains(query)) {
      final updatedHistory = List.from(searchHistory)..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    try {
      final results = await Future.wait<List<dynamic>>([
        fetchSongsList(query),
        searchArtists(query),
        fetchLivesList(query),
        getPlaylists(query: query, type: 'album'),
        getPlaylists(query: query, type: 'playlist'),
      ]);

      if (!mounted || requestId != _latestSearchRequest) return;

      _songsSearchResult = results[0];
      _artistsSearchResult = results[1]
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (_songsSearchResult.isEmpty && _artistsSearchResult.isNotEmpty) {
        _songsSearchResult = await _fetchSongsForResolvedArtist(query);
      }
      _livesSearchResult = results[2];
      _albumsSearchResult = results[3];
      _playlistsSearchResult = results[4];

      // Filter radio stations by name or genre
      _radioStationsSearchResult = radioStationsDB
          .where(
            (station) =>
                station.name.toLowerCase().contains(query.toLowerCase()) ||
                (station.genre?.toLowerCase().contains(query.toLowerCase()) ??
                    false),
          )
          .toList();
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _fetchingSongs.value = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final showSongs = _activeFilters.contains(SearchResultFilter.songs);
    final showPlaylists = _activeFilters.contains(SearchResultFilter.playlists);
    final showLives = _activeFilters.contains(SearchResultFilter.lives);
    final hasSongsResults = showSongs && _songsSearchResult.isNotEmpty;
    final hasLivesResults = showLives && _livesSearchResult.isNotEmpty;
    final hasAlbumResults = showPlaylists && _albumsSearchResult.isNotEmpty;
    final hasPlaylistResults = showPlaylists && _playlistsSearchResult.isNotEmpty;
    final hasAnyResults =
        hasSongsResults || hasLivesResults || hasAlbumResults || hasPlaylistResults;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final bar = ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWide ? 600 : double.infinity,
                  ),
                  child: CustomSearchBar(
                    loadingProgressNotifier: _fetchingSongs,
                    controller: _searchBar,
                    focusNode: _inputNode,
                    labelText: '${context.l10n!.search}...',
                    onChanged: (value) {
                      // debounce suggestions to avoid rapid API calls
                      _debounce?.cancel();
                      final query = value;
                      final requestId = ++_latestSuggestionRequest;

                      // Clear suggestions immediately if input is empty
                      if (query.isEmpty) {
                        _suggestionsList = [];
                        if (mounted) setState(() {});
                        return;
                      }

                      _debounce = Timer(
                        const Duration(milliseconds: 300),
                        () async {
                          final searchSuggestions = await getSearchSuggestions(
                            query,
                          );

                          if (!mounted ||
                              requestId != _latestSuggestionRequest ||
                              _searchBar.text != query) {
                            return;
                          }

                          _suggestionsList = List<String>.from(
                            searchSuggestions,
                          );
                          if (mounted) setState(() {});
                        },
                      );
                    },
                    onSubmitted: (String value) {
                      _submitSearch();
                    },
                  ),
                );
                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [bar],
                  );
                } else {
                  return bar;
                }
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: SearchResultFilter.values.map((filter) {
                  final isSelected = _activeFilters.contains(filter);
                  return FilterChip(
                    label: Text(_filterLabelFor(context, filter)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _activeFilters.add(filter);
                        } else if (_activeFilters.length > 1) {
                          _activeFilters.remove(filter);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child:
                  (_suggestionsList.isNotEmpty ||
                      (_songsSearchResult.isEmpty &&
                          _artistsSearchResult.isEmpty &&
                          _albumsSearchResult.isEmpty &&
                          _playlistsSearchResult.isEmpty &&
                          _radioStationsSearchResult.isEmpty))
                  ? ValueListenableBuilder<List>(
                      valueListenable: searchHistoryNotifier,
                      builder: (context, searchHistory, _) {
                        final items = _suggestionsList.isEmpty
                            ? searchHistory
                            : _suggestionsList;

                        return Column(
                          key: ValueKey(
                            'history-${_suggestionsList.length}-${_searchBar.text}-${searchHistory.length}',
                          ),
                          children: [
                            for (int index = 0; index < items.length; index++)
                              Builder(
                                builder: (context) {
                                  final query = items[index];
                                  final borderRadius = getItemBorderRadius(
                                    index,
                                    items.length,
                                  );

                                  return CustomBar(
                                    query,
                                    FluentIcons.search_24_regular,
                                    borderRadius: borderRadius,
                                    onTap: () async {
                                      await _submitSearch(query.toString());
                                    },
                                    onLongPress: () async {
                                      final confirm =
                                          await _showConfirmationDialog(
                                            context,
                                          ) ??
                                          false;
                                      if (confirm &&
                                          searchHistory.contains(query)) {
                                        final updatedHistory = List.from(
                                          searchHistory,
                                        )..remove(query);
                                        searchHistoryNotifier.value =
                                            updatedHistory;
                                        unawaited(
                                          addOrUpdateData<List>(
                                            'user',
                                            'searchHistory',
                                            updatedHistory,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    )
                  : _buildSearchResults(
                      context,
                      primaryColor,
                      showSongs: showSongs,
                      showPlaylists: showPlaylists,
                      showLives: showLives,
                    ),
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    Color primaryColor, {
    required bool showSongs,
    required bool showPlaylists,
    required bool showLives,
  }) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            borderRadius: borderRadius,
            onTap: () {
              context.push(
                '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Lives section
    if (showLives && _livesSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          Localizations.localeOf(context).languageCode == 'fr' ? 'En direct' : 'Live',
          primaryColor,
          icon: FluentIcons.live_24_filled,
        ),
      );

      final livesCount = _livesSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _livesSearchResult.length;

      for (var index = 0; index < livesCount; index++) {
        final borderRadius = getItemBorderRadius(index, livesCount);
        widgets.add(
          SongBar(
            _livesSearchResult[index],
            true,
            key: listItemKey('search_live', index, _livesSearchResult[index]),
            showMusicDuration: false,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Songs section
    if (showSongs && _songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Albums section
    if (showPlaylists && _albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (showPlaylists && _playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    // Radio Stations section
    if (_radioStationsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.radioStations,
          primaryColor,
          icon: FluentIcons.speaker_2_24_filled,
        ),
      );

      final stationsCount = _radioStationsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _radioStationsSearchResult.length;

      for (var index = 0; index < stationsCount; index++) {
        final station = _radioStationsSearchResult[index];
        final isLast = index == stationsCount - 1;

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: RadioStationCard(
              key: listItemKey('search_radio_station', index, station),
              station: station,
              onPressed: () async {
                final success = await audioHandler.playRadioStream(
                  id: station.id,
                  name: station.name,
                  streamUrl: station.streamUrl,
                  image: station.image,
                  genre: station.genre,
                );
                if (!success && context.mounted) {
                  showToast(context, context.l10n!.failedPlayingRadio);
                }
              },
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_livesSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  String _filterLabelFor(BuildContext context, SearchResultFilter filter) {
    switch (filter) {
      case SearchResultFilter.songs:
        return context.l10n!.songs;
      case SearchResultFilter.playlists:
        return context.l10n!.playlists;
      case SearchResultFilter.lives:
        return Localizations.localeOf(context).languageCode == 'fr'
            ? 'En direct'
            : 'Live';
    }
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
