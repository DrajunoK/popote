# Popote

Planifiez les repas à plusieurs, la liste de courses se fait toute seule.
Application Flutter (Android d'abord, iOS ensuite). Specs et maquettes : [`specs/`](specs/).

## Démarrer

Les dossiers `android/` et `ios/` ne sont pas versionnés ici : ils sont générés par Flutter.

```bash
# 1. Une seule fois, à la racine du projet (ne touche ni lib/ ni pubspec.yaml s'ils existent)
flutter create --org app.popote --project-name popote --platforms android,ios .

# 2. Dépendances + vérifications
flutter pub get
flutter analyze
flutter test

# 3. Lancer
flutter run
```

À faire dans le projet Android généré :

- `android/app/src/main/AndroidManifest.xml` : ajouter
  `<uses-permission android:name="android.permission.INTERNET"/>` (le plugin `google_fonts`
  télécharge Fraunces / Inter au premier lancement ; les builds *release* n'ont pas Internet par défaut).
- `minSdk` à 26 (Android 8.0) dans `android/app/build.gradle`.
- L'identifiant `app.popote` est un choix par défaut : il est figé après la première publication
  (spec §9) — changez `--org` avant le premier build si besoin.

## Ce qui est fait (v0.1)

| Spec | État |
|---|---|
| Thèmes Nuit (défaut) / Terracotta / Menthe / Myrtille, tokens `ThemeExtension`, aperçu immédiat | fait |
| Navigation adaptative : barre en bas < 600 dp, rail ≥ 600 dp, 2 panneaux paysage | fait |
| Planning semaine (téléphone), bottom sheet « Choisir un repas », actions sur un repas | fait |
| Planning tablette : grille + bibliothèque, glisser-déposer | fait |
| Bouton magique (algorithme glouton §3.8, verrous, relancer, annuler 10 s) | fait |
| Recettes : grille, recherche, filtres, favoris, fiche (portions), éditeur, repas « simple » | fait |
| Liste de courses : génération, agrégation, rayons, cocher, ajout libre, swipe, partage texte | fait |
| Groupes : créer, changer, QR + lien (local), créneaux | fait (local) |
| Profil : thème, rappel, déconnexion, suppression de compte | fait |
| 22 recettes de démarrage catégorisées | fait |

## Ce qui reste (voir spec §7)

- **Backend** : Supabase (Auth Google, Realtime, RLS, Storage). Aujourd'hui tout est local
  (`lib/data/app_store.dart`, JSON dans `SharedPreferences`) et la connexion Google est simulée
  (`lib/features/auth/login_screen.dart`). L'interface du store est celle à brancher sur Drift + Supabase.
- Hors-ligne avec file de synchronisation, invitations réelles (jetons, App Links), rôles appliqués.
- Photos de recettes, import par URL, widget Android, notifications.
- i18n anglais (les textes sont en français dans le code), tailles de texte, autocomplétion des produits,
  échange de deux jours par glisser dans le bouton magique, vue mois / jour.
- Sign in with Apple, Universal Links (iOS).

## Structure

```
lib/
  core/       thème (tokens), routeur, formats
  data/       modèles, état local, données de démarrage
  domain/     logique pure et testée : liste de courses, bouton magique, catégorisation
  shared/     widgets réutilisables
  features/   auth, shell, planner, recipes, shopping, groups, profile
test/         tests unitaires de la logique métier
```

## Photos des recettes

Les repas affichent un emoji déduit du titre (`lib/domain/recipe_emoji.dart`) tant qu'aucune photo n'est ajoutée.
Les clés iOS suivantes sont déjà dans `ios/Runner/Info.plist` :

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Choisir une photo pour vos recettes.</string>
<key>NSCameraUsageDescription</key>
<string>Prendre une photo de vos plats.</string>
```

Android n'a besoin d'aucune permission pour `image_picker` (sélecteur système). La photo n'est pas disponible sur le web.
