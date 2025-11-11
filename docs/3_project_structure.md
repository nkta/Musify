# 3. Structure du Projet

Le projet est organisé de manière conventionnelle pour une application Flutter, favorisant la modularité et la maintenabilité.

```
/
├── android/            # Fichiers de projet spécifiques à Android
├── assets/             # Fichiers statiques (licences, etc.)
├── fonts/              # Polices de caractères personnalisées
├── lib/                # Code source Dart de l'application
│   ├── API/            # Logique pour interagir avec les API externes
│   ├── DB/             # Schémas et gestion de la base de données Hive
│   ├── extensions/     # Méthodes d'extension Dart
│   ├── localization/   # Fichiers de traduction (.arb)
│   ├── models/         # Classes de modèle de données (POCOs)
│   ├── screens/        # Widgets représentant les pages de l'application
│   ├── services/       # Services contenant la logique métier
│   ├── style/          # Thèmes, couleurs et styles
│   ├── utilities/      # Fonctions et classes utilitaires
│   └── widgets/        # Widgets réutilisables
│
├── test/               # Tests unitaires et d'intégration
├── .github/            # Fichiers relatifs à GitHub
│   └── workflows/      # Workflows CI/CD (GitHub Actions)
│
├── pubspec.yaml        # Manifeste du projet (dépendances, version)
├── README.md           # Présentation générale du projet
└── DOCUMENTATION.md    # Portail de cette documentation
```

## Description des Dossiers Clés (`lib/`)

*   **`API/`**: Contient la logique d'abstraction pour communiquer avec les sources de données externes. Le fichier `musify.dart` est central ici, utilisant `youtube_explode_dart` pour interagir avec YouTube.

*   **`DB/`**: Définit les "boîtes" (tables) Hive pour la base de données locale. `albums.db.dart` et `playlists.db.dart` gèrent la structure des données persistées.

*   **`localization/`**: Contient les fichiers `app_XX.arb` pour l'internationalisation (i18n), permettant à l'application de supporter plusieurs langues.

*   **`models/`**: Abrite les objets de données simples (Plain Old Dart Objects). Ces classes définissent la structure des données manipulées par l'application, comme `PositionData` pour la lecture audio.

*   **`screens/`**: Chaque fichier correspond à une page principale de l'application (ex: `home_page.dart`, `search_page.dart`, `settings_page.dart`). Ces widgets sont "scaffoldés" et gèrent la mise en page globale.

*   **`services/`**: Le cerveau de l'application. Ces classes ne sont pas des widgets et gèrent des tâches de fond ou complexes :
    *   `audio_service.dart`: Gère la lecture audio en arrière-plan.
    *   `playlist_download_service.dart`: S'occupe du téléchargement des chansons.
    *   `data_manager.dart`: Agit comme une façade pour interagir avec la base de données (`DB/`).

*   **`style/`**: Définit l'apparence de l'application. `app_themes.dart` contient la logique pour les thèmes clair, sombre et dynamique (Material You).

*   **`widgets/`**: Contient des composants d'UI réutilisables à travers différentes pages, comme `song_bar.dart` (une ligne dans une liste de chansons) ou `playlist_artwork.dart` (la pochette d'une playlist).
