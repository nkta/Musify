# 1. Introduction et Fonctionnalités

## Présentation Générale

**Musify** est une application de streaming musical open-source développée avec le framework **Flutter**. Elle permet aux utilisateurs d'écouter de la musique principalement en extrayant les flux audio de sources externes comme YouTube, offrant ainsi une expérience sans publicité et sans abonnement.

L'application est conçue pour être une alternative libre et respectueuse de la vie privée aux services de streaming commerciaux. Elle met l'accent sur la personnalisation, l'écoute hors ligne et une interface utilisateur moderne.

## Fonctionnalités Principales

```mermaid
graph TD
    subgraph "Fonctionnalités Clés"
        A[Streaming via URL]
        B[Recherche en Ligne]
        C[Écoute Hors Ligne]
        D[Gestion des Données (Import/Export)]
        E[Affichage des Paroles]
        F[SponsorBlock Intégré]
        G[UI Material You & Thèmes]
        H[Gratuit, Sans Pubs ni Abonnement]
        I[Mises à Jour Intégrées]
        J[Support Multilingue (22 langues)]
    end

    User((Utilisateur)) --> A
    User --> B
    User --> C
    User --> D
    User --> E
    User --> F
    User --> G
    User --> H
    User --> I
    User --> J

    style User fill:#f9f,stroke:#333,stroke-width:4px
```

*   **Streaming depuis une URL** : Lecture audio directe à partir d'un lien YouTube.
*   **Recherche en Ligne** : Recherche de chansons avec suggestions.
*   **Écoute Hors Ligne** : Prise en charge du téléchargement de chansons et de playlists pour une écoute sans connexion internet.
*   **Gestion des Données** : Possibilité d'importer et d'exporter les données de l'utilisateur (playlists, favoris).
*   **Paroles** : Affichage des paroles des chansons en cours de lecture.
*   **SponsorBlock** : Intégration pour sauter les segments sponsorisés, les intros et autres interruptions.
*   **Interface Utilisateur** :
    *   Interface basée sur Material Design.
    *   Prise en charge des couleurs dynamiques (Material You) sur Android 12+.
    *   Thèmes clair et sombre.
*   **Gratuit et Sans Publicité** : Aucune publicité ni aucun abonnement requis.
*   **Internationalisation** : L'application est disponible dans 22 langues.
*   **Mises à jour intégrées** : L'application dispose d'un mécanisme de mise à jour interne.
