# 4. Dépendances Principales

Musify s'appuie sur un écosystème de bibliothèques open-source robustes pour fournir ses fonctionnalités. Voici les plus importantes :

## Diagramme des Dépendances Clés

Ce diagramme montre comment les principales dépendances s'intègrent dans les différentes couches de l'application.

```mermaid
graph TD
    subgraph "Couche UI & Navigation"
        A[go_router]
        B[dynamic_color]
        C[cached_network_image]
    end

    subgraph "Couche Audio"
        D[audio_service]
        E[just_audio]
        F[rxdart]
        D --> E
        D --> F
    end

    subgraph "Couche Données & API"
        G[youtube_explode_dart]
        H[hive]
        I[http]
    end

    style A fill:#87CEEB
    style B fill:#87CEEB
    style C fill:#87CEEB
    style D fill:#98FB98
    style E fill:#98FB98
    style F fill:#98FB98
    style G fill:#FFDAB9
    style H fill:#E6E6FA
    style I fill:#FFDAB9
```

## Description des Dépendances

| Bibliothèque             | Rôle                                                                                                | Couche        |
| ------------------------ | --------------------------------------------------------------------------------------------------- | ------------- |
| **`go_router`**          | Gère la navigation et les URL au sein de l'application de manière déclarative.                      | UI            |
| **`just_audio`**         | Un lecteur audio puissant et hautement personnalisable pour la lecture des flux.                    | Audio         |
| **`audio_service`**      | Permet à `just_audio` de fonctionner en arrière-plan et de s'intégrer avec le système d'exploitation (notifications, contrôles de l'écran de verrouillage). | Audio         |
| **`youtube_explode_dart`** | La dépendance la plus critique. Elle fournit les outils pour extraire les métadonnées et les URL de flux audio directement depuis YouTube sans utiliser leur API officielle. | API           |
| **`hive` / `hive_flutter`** | Une base de données NoSQL "clé-valeur" extrêmement rapide, utilisée pour tout le stockage local (playlists, cache, paramètres). | Données       |
| **`rxdart`**             | Fournit des classes et des opérateurs de programmation réactive (Streams), essentiels pour gérer les états complexes des flux audio. | Audio         |
| **`dynamic_color`**      | Implémente le theming dynamique "Material You" en extrayant les couleurs du fond d'écran de l'utilisateur (Android 12+). | UI            |
| **`cached_network_image`** | Télécharge et met en cache les images (pochettes d'album) pour une meilleure performance et une utilisation réduite des données. | UI            |
| **`http`**               | Un client HTTP standard pour effectuer des requêtes réseau de base (par exemple, pour les paroles). | API           |
