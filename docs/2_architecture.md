# 2. Architecture de l'Application

L'architecture de Musify est modulaire, séparant clairement l'interface utilisateur (UI), la logique métier (Services) et l'accès aux données (API, DB).

## Diagramme des Composants

Ce diagramme illustre la structure générale et les interactions entre les principaux modules.

```mermaid
graph TD
    subgraph "Application Musify"
        A[Couche UI<br>Screens & Widgets] --> B(Couche Services<br>Logique Métier)
        B --> C[Couche API<br>Accès Données Externes]
        B --> D[Couche Données<br>Base de données locale]
    end

    Utilisateur --> A
    C --> E[Source Audio<br>ex: YouTube]
    C --> F[Source Paroles]
    D --> G[Fichiers Audio<br>Données Hors Ligne]

    style A fill:#87CEEB
    style B fill:#98FB98
    style C fill:#FFDAB9
    style D fill:#E6E6FA
```

*   **Couche UI** (`lib/screens`, `lib/widgets`): Responsable de l'affichage. Elle est construite en Flutter et ne contient aucune logique métier complexe.
*   **Couche Services** (`lib/services`): Le cœur de l'application. Elle orchestre les actions, traite les données et fait le lien entre l'UI et les sources de données.
*   **Couche API** (`lib/API`): Gère la communication avec les services externes (recherche, streaming, paroles).
*   **Couche Données** (`lib/DB`): Gère la persistance des données sur l'appareil (playlists, paramètres) avec la base de données Hive.

## Flux de Données : Recherche et Lecture d'une Chanson

Ce diagramme de séquence montre les étapes détaillées lorsqu'un utilisateur recherche et lance une chanson.

```mermaid
sequenceDiagram
    participant User as Utilisateur
    participant UI as Interface (Screen)
    participant Services as Couche Services
    participant API as Couche API
    participant Source as Source Externe (YouTube)
    participant Player as Lecteur Audio (just_audio)

    User->>+UI: 1. Saisit une recherche
    UI->>+Services: 2. searchSongs("requête")
    Services->>+API: 3. fetchSongs("requête")
    API->>+Source: 4. Requête HTTP de recherche
    Source-->>-API: 5. Retourne les résultats
    API-->>-Services: 6. Retourne les chansons parsées
    Services-->>-UI: 7. Met à jour l'état avec les résultats
    UI-->>-User: 8. Affiche la liste des chansons

    User->>+UI: 9. Clique sur une chanson
    UI->>+Services: 10. playSong(song)
    Services->>+API: 11. getAudioStream(song)
    API->>+Source: 12. Récupère l'URL du flux audio
    Source-->>-API: 13. Retourne l'URL
    API-->>-Services: 14. Transmet l'URL du flux
    Services->>+Player: 15. setAudioSource(url)
    Player-->>-Services: 16. Le lecteur commence la lecture
    Services-->>-UI: 17. Met à jour l'état (lecture en cours)
    UI-->>-User: 18. L'interface indique la lecture
```
