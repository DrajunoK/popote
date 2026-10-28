# Spécifications — Application de planification de repas (Android → iOS)

> Nom : **Popote** — framework : **Flutter** (validé)
> Version du document : 0.1 — 27 octobre 2026
> Cibles : Android téléphone + tablette (v1), puis iOS iPhone + iPad (v2)

---

## 1. Vision

Une application familiale et collaborative pour **planifier les repas** (semaine, weekend, année), **piocher dans une bibliothèque de recettes** (avec favoris), et **générer automatiquement la liste de courses**, enrichie librement de produits hors recettes.

Le partage se fait via des **groupes** (famille, colocation, amis pour un weekend) : chaque groupe a son planning et sa liste de courses partagés, synchronisés en temps réel.

### Objectifs
- Planifier une semaine en **moins de 2 minutes**.
- Une liste de courses **générée en 1 tap**, regroupée par rayon, cochable en magasin.
- Fonctionnement **hors-ligne** au supermarché (zones sans réseau).
- Une base de code pensée dès le départ pour le **portage iOS**.

### Hors périmètre v1
- Calcul nutritionnel détaillé, commande en ligne / drive, import automatique de recettes depuis le web (prévu v1.x), monétisation.

---

## 2. Personas

| Persona | Besoin principal |
|---|---|
| **Le planificateur** (parent organisateur) | Préparer la semaine le dimanche, éviter de répéter les mêmes plats, générer la liste. |
| **Le contributeur** (conjoint, ado) | Consulter « on mange quoi ce soir », proposer un repas, cocher en magasin. |
| **L'invité ponctuel** (amis d'un weekend chalet) | Rejoindre un groupe temporaire via un lien, voir le planning et la liste du weekend. |

---

## 3. Fonctionnalités

### 3.1 Authentification
- **F-AUTH-01** Connexion via **Google Sign-In** (Android Credential Manager).
- **F-AUTH-02** Session persistante, déconnexion depuis le profil.
- **F-AUTH-03** Suppression de compte + données (exigence Google Play & App Store).
- **F-AUTH-04** (iOS, v2) **Sign in with Apple** obligatoire dès qu'un login tiers est proposé sur l'App Store.

### 3.2 Groupes
- **F-GRP-01** Créer un groupe : nom, emoji/couleur, **type de période** :
  - *Semaine* (planning glissant hebdo),
  - *Weekend / séjour* (dates de début et fin, ex. 3 jours au chalet),
  - *Annuel* (planning long terme, vue mois).
- **F-GRP-02** Inviter par **lien / QR code** (deep link) ou par e-mail. Le lien expire (7 jours par défaut, configurable).
- **F-GRP-03** Rôles : **Admin** (gère membres et paramètres), **Membre** (édite planning, recettes du groupe, liste), **Lecteur** (consulte, coche la liste).
- **F-GRP-04** Un utilisateur peut appartenir à **plusieurs groupes** ; sélecteur de groupe en haut de l'écran.
- **F-GRP-05** Un **espace personnel** (groupe implicite à 1 membre) existe par défaut.
- **F-GRP-06** Quitter / archiver un groupe ; un groupe *Weekend* s'archive automatiquement 7 jours après sa date de fin.

### 3.3 Bibliothèque de repas / recettes
- **F-REC-01** Liste des repas avec recherche plein texte, filtres (catégorie, temps de préparation, tags : végétarien, rapide, batch cooking, enfants…).
- **F-REC-02** Fiche recette : photo, titre, portions, temps (préparation/cuisson), ingrédients (quantité + unité + rayon), étapes, tags, notes.
- **F-REC-03** **Créer / modifier / dupliquer** une recette. Un repas peut être « simple » (juste un titre, ex. « Pizza maison », sans ingrédients) pour ne pas bloquer la planification.
- **F-REC-04** **Favoris** (par utilisateur) — cœur sur la carte et la fiche.
- **F-REC-05** Portée d'une recette : **personnelle** ou **partagée au groupe**. Une recette personnelle peut être copiée dans un groupe.
- **F-REC-06** **Recettes de démarrage** : catalogue initial de recettes familiales françaises proposé à la création du compte.
- **F-REC-07** Ajustement des portions → recalcul des quantités.
- **F-REC-08** Historique : « dernière fois cuisiné le… » pour éviter les répétitions.
- **F-REC-09** (v1.x) Import depuis une URL (schema.org/Recipe).
- **F-REC-10** **Catégorisation** de chaque repas (utilisée par le bouton magique et les filtres) :

  | Axe | Valeurs | Obligatoire |
  |---|---|---|
  | **Protéine principale** | Bœuf/veau, Porc, Volaille, Poisson & fruits de mer, Œufs, Végétarien, Vegan | Oui |
  | **Base** | Pâtes, Riz, Pommes de terre, Pain/pâte (pizza, tarte, croque), Légumineuses, Céréales (semoule, quinoa), Légumes seuls | Oui |
  | **Type de plat** | Gratin/four, Mijoté, Poêlée/wok, Soupe, Salade, Tarte/quiche, Grillade, Plat froid | Non |
  | **Effort** | Rapide (< 30 min), Normal, Long (week-end) — déduit du temps total, modifiable | Auto |
  | **Saison** | Toute l'année, Printemps-été, Automne-hiver | Non (défaut : toute l'année) |
  | **Cuisine** | Française, Italienne, Asiatique, Mexicaine, Orientale… | Non |
  | **Enfants** | Apprécié des enfants (oui/non) | Non |

  - Saisie rapide : chips pré-remplies à la création ; suggestion automatique de la protéine et de la base à partir des ingrédients (ex. « lardons » → Porc, « spaghetti » → Pâtes).
  - Les recettes de démarrage sont livrées déjà catégorisées.
  - Badge couleur par protéine sur les cartes (vert = végé, bleu = poisson, moutarde = volaille, terracotta = bœuf, rose = porc).

### 3.4 Planning
- **F-PLN-01** Vue **semaine** (défaut téléphone), **jour**, **mois** (groupes annuels).
- **F-PLN-02** Créneaux configurables par groupe : *Petit-déj, Midi, Goûter, Dîner* (par défaut Midi + Dîner).
- **F-PLN-03** Ajouter un repas à un créneau : bottom sheet avec onglets **Favoris / Récents / Tous / Créer**.
- **F-PLN-04** **Glisser-déposer** un repas d'un créneau à l'autre (tablette surtout) ; appui long → déplacer / dupliquer / supprimer.
- **F-PLN-05** Nombre de convives par créneau (défaut = taille du groupe) → impacte les quantités de la liste.
- **F-PLN-06** Notes libres par créneau (« restes », « au resto », « chez mamie »).
- **F-PLN-07** **Bouton magique « Planifie ma semaine »** : remplit automatiquement les créneaux vides en variant les repas — voir §3.8.
- **F-PLN-08** Copier une semaine / sauvegarder une semaine type comme **modèle**.
- **F-PLN-09** Widget écran d'accueil Android : « Ce soir on mange… ».

### 3.5 Liste de courses
- **F-SHP-01** **Générer** la liste pour une plage de dates (par défaut : semaine affichée) à partir des recettes planifiées.
- **F-SHP-02** **Agrégation intelligente** des ingrédients identiques (2 × 200 g de farine → 400 g), conversion d'unités compatibles (g/kg, ml/l).
- **F-SHP-03** Regroupement par **rayon** (Fruits & légumes, Frais, Épicerie, Surgelés, Boissons, Hygiène, Maison, Autre).
- **F-SHP-04** **Ajout libre** de produits hors recettes (« papier toilette », « lessive ») avec autocomplétion sur l'historique.
- **F-SHP-05** Cocher / décocher, éléments cochés déplacés en bas ; « Vider les cochés ».
- **F-SHP-06** Indicateur de provenance : quelle(s) recette(s) a/ont généré l'article.
- **F-SHP-07** Régénération non destructive : les ajouts manuels et les cases cochées sont conservés.
- **F-SHP-08** Synchronisation **temps réel** entre membres (deux personnes en magasin).
- **F-SHP-09** **Mode hors-ligne** complet, synchronisation au retour du réseau.
- **F-SHP-10** Partage texte de la liste (WhatsApp, SMS) pour les non-utilisateurs.
- **F-SHP-11** Placard / « déjà à la maison » : exclure des produits de base (sel, huile…) de la génération.

### 3.6 Notifications (v1.x)
- Rappel du dimanche « Planifie ta semaine », notification quand un membre modifie le planning ou la liste.

### 3.7 Profil & réglages
- **F-PRF-01** Accès via l'avatar en haut du planning.
- **F-PRF-02** **Apparence** : choix du thème — **Nuit (défaut)**, Terracotta, Menthe, Myrtille — avec aperçu immédiat. Préférence enregistrée par utilisateur et synchronisée entre appareils.
- **F-PRF-03** Taille du texte (suit le réglage système, + option « grande liste de courses » en magasin).
- **F-PRF-04** Langue (Français / English), unités.
- **F-PRF-05** Notifications (rappel du dimanche, modifications du groupe).
- **F-PRF-06** Compte : nom, avatar Google, export des données, déconnexion, suppression du compte.

### 3.8 Bouton magique — planification automatique
**Objectif** : en 1 tap, proposer une semaine variée, équilibrée et réaliste, que l'utilisateur ajuste avant de valider.

**Parcours**
1. Depuis le planning, bouton ✦ **« Planifie ma semaine »** (ou « Planifie le weekend » pour un groupe séjour).
2. Écran de réglages rapides (mémorisés par groupe) : créneaux à remplir (Midi / Dîner), règles activées (voir ci-dessous), « garder les repas déjà planifiés » (coché par défaut).
3. **Aperçu** de la proposition jour par jour, avec badge de catégorie et résumé « équilibre de la semaine » (ex. 2 végé · 1 poisson · 2 volaille · 1 bœuf · 1 porc).
4. Sur chaque ligne : **cadenas** pour verrouiller un repas, **tap** pour remplacer à la main, **glisser** pour échanger deux jours.
5. **« Relancer »** régénère uniquement les lignes non verrouillées. **« Valider »** écrit dans le planning (annulable via « Annuler » pendant 10 s).

**Règles (configurables par groupe)**

| Règle | Défaut |
|---|---|
| Pas la même protéine deux repas de suite (midi → dîner, dîner → midi du lendemain) | Oui |
| Pas la même base deux jours de suite ; max 2 fois la même base par semaine | Oui |
| Pas le même type de plat (ex. 2 gratins) deux jours de suite | Oui |
| Minimum de repas végétariens par semaine | 2 |
| Minimum de repas poisson par semaine | 1 |
| Maximum de viande rouge par semaine | 2 |
| Repas « Rapide » en semaine (lun–ven), « Long » autorisé le week-end | Oui |
| Pas de recette déjà cuisinée dans les 14 derniers jours | Oui (10–21 j réglable) |
| Respect de la saison | Oui |
| Midi et dîner du même jour : protéines différentes | Oui |
| Favoris privilégiés (pondération) | ×2 |
| Proposer « Restes » le midi suivant une recette ≥ 6 portions | Non |

**Algorithme (v1)** — remplissage glouton avec score, exécuté localement (fonctionne hors-ligne) :
1. Candidats = recettes du groupe + personnelles, filtrées par saison, historique (14 j) et effort selon le jour.
2. Les créneaux sont traités dans l'ordre chronologique ; les repas déjà présents/verrouillés servent de contraintes.
3. Pour chaque créneau, chaque candidat reçoit un score :
   `score = poids_favori × fraîcheur (jours depuis la dernière fois) − pénalités`
   - pénalité forte (exclusion) si une règle « dure » est violée (même protéine consécutive, recette déjà utilisée dans la semaine) ;
   - pénalité moyenne si un quota risque de ne plus être atteignable (ex. il reste 2 créneaux et 0 poisson) → bonus aux catégories manquantes ;
   - pénalité légère pour une base/cuisine déjà vue dans la semaine.
4. Tirage **aléatoire pondéré** parmi les 5 meilleurs scores (pour que « Relancer » donne vraiment autre chose).
5. Si aucun candidat ne passe : relâcher progressivement les règles « souples » et l'indiquer (« Pas assez de recettes poisson — ajoutez-en ou désactivez la règle »).
6. Seed aléatoire conservé pour pouvoir annuler/rejouer.

**Cas limites**
- Moins de 7 recettes éligibles : remplir ce qui est possible + message d'invitation à ajouter des recettes.
- Repas « simples » non catégorisés : utilisés uniquement si la catégorie a été renseignée, sinon ignorés par l'algo.
- Groupe séjour (weekend chalet) : prise en compte du nombre de convives et préférence pour les plats « grande tablée » (gratins, mijotés).

**Évolutions (v2)** : apprentissage des refus (« on ne relance jamais la blanquette »), notes 👍/👎 après le repas, prise en compte du contenu du placard, budget.

---

## 4. Exigences non fonctionnelles

| Domaine | Exigence |
|---|---|
| Plateformes | Android 8.0+ (API 26). iOS 16+ en v2. |
| Adaptatif | Téléphone (compact), tablette / pliable (medium, expanded) — voir §6.3. |
| Hors-ligne | Lecture complète + écriture du planning et de la liste hors-ligne (local-first). |
| Performance | Démarrage à froid < 2 s, navigation < 100 ms, liste de 200 articles fluide à 60 fps. |
| Accessibilité | WCAG 2.2 AA : contrastes, tailles de police dynamiques, TalkBack/VoiceOver, cibles tactiles ≥ 48 dp. |
| Langues | Français (défaut), Anglais. Architecture i18n dès le départ. |
| Thèmes | **Nuit par défaut** ; Terracotta, Menthe, Myrtille au choix dans le Profil (voir §6.2). |
| RGPD | Données hébergées UE, export des données, suppression de compte, politique de confidentialité. |
| Sécurité | Row Level Security côté backend : un utilisateur ne lit que ses groupes. |

---

## 5. Architecture technique

### 5.1 Choix du framework mobile

| Option | Avantages | Inconvénients |
|---|---|---|
| **Flutter** (recommandé) | Un seul code Android + iOS, rendu identique, très bon support tablette, écosystème mature (Riverpod, Drift, go_router), hot reload. | Dart à apprendre ; look « Material » à adapter un peu sur iOS. |
| Kotlin + Compose Multiplatform | Kotlin natif Android, UI partagée iOS (stable). | Écosystème iOS plus jeune, moins de librairies prêtes. |
| Kotlin natif + SwiftUI | Meilleure intégration par plateforme. | Deux codes UI à maintenir — à éviter pour un projet perso. |

**Décision : Flutter.** Le portage iOS devient une question de configuration (signing, Sign in with Apple, tests) plutôt qu'une réécriture.

### 5.2 Backend

**Supabase** (Postgres + Auth + Realtime + Storage), région UE.
- Auth : provider **Google** (+ Apple en v2).
- **Realtime** pour la liste de courses et le planning partagés.
- **Storage** pour les photos de recettes (redimensionnées côté client, WebP).
- **RLS** sur toutes les tables, basée sur l'appartenance au groupe.
- **Edge Functions** : génération de la liste (agrégation), invitations, suggestions.

> Si le backend Supabase du projet web *meal-planner* existe déjà, l'app mobile peut le **réutiliser** : même schéma, même seed de recettes, web + mobile synchronisés. Seul ajout : le provider Google en plus du magic link.

Alternative : Firebase (Auth Google natif, Firestore offline) — plus simple pour l'offline, moins adapté aux requêtes relationnelles (agrégation d'ingrédients).

### 5.3 Architecture applicative (Flutter)

```
lib/
  core/          # thème, design tokens, routing (go_router), i18n, erreurs
  data/          # Supabase client, base locale Drift (SQLite), sync queue
  features/
    auth/
    groups/
    recipes/
    planner/
    shopping/
    profile/
  shared/        # widgets réutilisables (MealCard, SlotTile, EmptyState…)
```

- **État** : Riverpod.
- **Local-first** : Drift (SQLite) comme source de vérité UI ; file d'attente de mutations rejouée vers Supabase ; Realtime → mise à jour locale.
- **Conflits** : last-write-wins par champ, sauf cases à cocher de la liste (dernier état horodaté).
- **Deep links** : `https://<domaine>/join/<token>` (App Links Android / Universal Links iOS).

### 5.4 Modèle de données

```
users            (id, email, display_name, avatar_url, locale, created_at)
groups           (id, name, emoji, color, period_type[week|stay|year],
                  start_date?, end_date?, slots jsonb, planner_rules jsonb,
                  created_by, archived_at)
group_members    (group_id, user_id, role[admin|member|viewer], joined_at)
invitations      (id, group_id, token, role, expires_at, created_by)

recipes          (id, owner_id, group_id?, title, photo_url, servings,
                  prep_min, cook_min, steps jsonb, tags text[], notes,
                  protein, base, dish_type?, effort, season, cuisine?,
                  kid_friendly bool, is_simple bool, created_at, updated_at)
ingredients      (id, name, default_aisle, default_unit)           -- référentiel
recipe_ingredients (recipe_id, ingredient_id, quantity, unit, note)
favorites        (user_id, recipe_id)

plan_entries     (id, group_id, date, slot, recipe_id?, free_text?,
                  guests int, note, position, updated_by, updated_at)
plan_templates   (id, group_id, name, entries jsonb)

shopping_lists   (id, group_id, from_date, to_date, generated_at)
shopping_items   (id, list_id, ingredient_id?, label, quantity, unit,
                  aisle, source[recipe|manual], source_recipe_ids uuid[],
                  checked bool, checked_by, checked_at, position)
pantry_items     (group_id, ingredient_id)                         -- exclus
```

### 5.5 Algorithme de génération de la liste
1. Récupérer les `plan_entries` du groupe sur la plage de dates avec une recette.
2. Pour chaque entrée : facteur = `guests / recipe.servings`.
3. Multiplier chaque `recipe_ingredient` par le facteur, normaliser l'unité (g, ml, pièce).
4. Grouper par `(ingredient_id, unité normalisée)`, sommer, arrondir intelligemment (0,4 oignon → 1 oignon).
5. Exclure les `pantry_items`.
6. Fusionner avec la liste existante : mettre à jour les articles `source=recipe`, conserver les `manual` et l'état `checked`.

---

## 6. Design

### 6.1 Principes
- **Mode Nuit par défaut** : fond sombre profond, accent orange chaud, menthe pour les validations — confortable le soir (moment où on planifie) et en cuisine. Les autres thèmes restent au choix dans le Profil.
- **Chaleureux et appétissant** : on parle de cuisine, pas de tableur — accents chauds, titres en serif.
- **Une main, un pouce** : actions principales en bas de l'écran, bottom sheets plutôt que nouvelles pages.
- **Photo d'abord** pour les recettes, **texte d'abord** pour la liste de courses (lisible en magasin).
- **Material 3** comme base (composants, accessibilité), personnalisé avec les tokens ci-dessous.

### 6.2 Design tokens

**Thème par défaut : Nuit**

| Token | Nuit (défaut) |
|---|---|
| `background` | `#14161B` |
| `surface` | `#1E2229` |
| `surface-variant` | `#262A32` |
| `outline` | `#2C313A` |
| `outline-strong` (pointillés, cases) | `#434A55` |
| `on-surface` | `#F1EEE8` |
| `on-surface-muted` | `#A7ACB5` |
| `primary` (orange chaud) | `#F2994A` — texte dessus `#14161B` |
| `primary-container` | `#3A2A1C` — texte dessus `#F7B57A` |
| `secondary` (menthe) | `#8DD3A8` — texte dessus `#14161B` |
| `tertiary` (moutarde) | `#F2C35B` |
| `inverse` (chips actives, carte d'invitation) | fond `#F1EEE8`, texte `#14161B` |

**Thèmes au choix (Profil › Apparence)** — même structure de tokens, valeurs différentes :

| Thème | background | surface | on-surface | primary | secondary | Titres |
|---|---|---|---|---|---|---|
| **Nuit** (défaut) | `#14161B` | `#1E2229` | `#F1EEE8` | `#F2994A` | `#8DD3A8` | Fraunces |
| Terracotta | `#FBF7F1` | `#FFFFFF` | `#2A2420` | `#B54A33` | `#4A6B51` | Fraunces |
| Menthe | `#F3F7F5` | `#FFFFFF` | `#13261F` | `#1F6F5C` | `#B0452E` | Inter 700 |
| Myrtille | `#F5F3FF` | `#FFFFFF` | `#1D1A33` | `#4F3FD1` | `#3A6B12` | Space Grotesk |

- Implémentation Flutter : un `ThemeExtension` (`MijoteColors`) par thème + `ThemeData` Material 3 ; le thème choisi est un `Riverpod` provider persistant (stockage local + synchronisé au profil). Changement instantané, sans redémarrage.
- Les badges de catégorie (protéines) ont une variante sombre et une claire pour garder un contraste ≥ 4.5:1 dans chaque thème.
- **Typo** : titres *Fraunces* (serif chaleureuse) selon le thème, texte *Inter*.
- **Échelle** : 12 / 14 / 16 / 20 / 24 / 32.
- **Rayons** : 12 (chips, champs), 20 (cartes), 28 (bottom sheets).
- **Espacements** : base 4 — 8 / 12 / 16 / 24 / 32.
- **Couleurs de créneaux** : Petit-déj moutarde, Midi sauge, Dîner terracotta (pastilles discrètes).

### 6.3 Navigation adaptative

| Taille | Navigation | Layout |
|---|---|---|
| Téléphone (< 600 dp) | Barre de navigation en bas, 4 onglets | 1 panneau |
| Tablette portrait (600–840 dp) | Navigation rail à gauche | 1 à 2 panneaux |
| Tablette paysage (> 840 dp) | Navigation rail | **2 panneaux** : planning + bibliothèque côte à côte (glisser-déposer) |

Onglets : **Planning · Recettes · Courses · Groupe**. FAB contextuel (ajouter repas / recette / produit).

### 6.4 Écrans clés
1. **Onboarding & login** — illustration, « Continuer avec Google », choix : créer un groupe / rejoindre via lien / plus tard.
2. **Planning (semaine)** — sélecteur de groupe en haut, bandeau de jours horizontal, cartes de créneaux par jour ; créneau vide = bouton « + » en pointillé ; bouton « Remplir la semaine » et « Générer les courses ».
3. **Bottom sheet « Choisir un repas »** — recherche, onglets Favoris / Récents / Tous, cartes compactes avec photo, « + Créer un repas ».
4. **Bibliothèque de recettes** — grille de cartes photo (2 colonnes téléphone, 3–4 tablette), chips de filtres, cœur favori.
5. **Fiche recette** — grande photo, temps et portions (stepper), onglets Ingrédients / Étapes, bouton « Planifier ».
6. **Éditeur de recette** — formulaire progressif ; mode « simple » (juste un nom) mis en avant.
7. **Liste de courses** — progression (12/30), sections par rayon repliables, cases larges, champ d'ajout rapide collé en bas, article coché barré et grisé.
8. **Groupe** — membres avec avatars et rôles, QR code d'invitation, période du groupe, créneaux.
9. **Tablette paysage** — planning de la semaine à gauche, bibliothèque à droite, glisser une recette sur un créneau.

### 6.5 Micro-interactions
- Ajout au planning : la carte « vole » vers le créneau.
- Cocher un article : vibration légère + l'article glisse en bas.
- Glisser à gauche sur un article : supprimer ; à droite : modifier la quantité.
- États vides illustrés et utiles (« Aucun repas mardi — Ajouter ou Remplir automatiquement »).

---

## 7. Roadmap

| Phase | Contenu | Estimation (side project) |
|---|---|---|
| **0 — Fondations** | Projet Flutter, thème/tokens, Supabase (schéma, RLS), login Google | 2 semaines |
| **1 — MVP perso** | Recettes CRUD + favoris + seed, planning semaine, liste générée + ajouts manuels | 4–5 semaines |
| **2 — Partage** | Groupes, invitations par lien/QR, rôles, Realtime | 3 semaines |
| **3 — Robustesse** | Hors-ligne (Drift + sync), tablette 2 panneaux, accessibilité, i18n EN | 3 semaines |
| **4 — Publication Android** | Tests fermés Play Console (12 testeurs × 14 jours pour un compte perso), fiche store, politique de confidentialité | 2–3 semaines |
| **5 — iOS** | Sign in with Apple, Universal Links, adaptations Cupertino légères, TestFlight, App Store | 2–3 semaines |
| **v1.x** | Import URL, suggestions, modèles de semaine, widget, notifications | continu |

---

## 8. Critères d'acceptation MVP
- Je me connecte avec Google et retrouve mes données sur un 2ᵉ appareil.
- Je planifie 7 dîners en < 2 min depuis mes favoris.
- Je génère une liste dont les ingrédients communs sont agrégés et classés par rayon.
- J'ajoute « lessive » à la liste, je régénère : « lessive » est toujours là.
- Mon conjoint coche un article : je le vois coché en < 2 s.
- En mode avion, je coche des articles ; ils se synchronisent au retour du réseau.
- Sur tablette paysage, je glisse une recette sur un créneau.

---

## 9. Points ouverts
- Identifiant du package (ex. `app.popote` ou `ch.popote.app`, figé après la 1ʳᵉ publication) et domaine pour les deep links — vérifier la disponibilité de « Popote » sur les stores et à l'INPI.
- Réutiliser le backend Supabase du projet web existant ou repartir de zéro ?
- Unités : métrique uniquement, ou support cup/tbsp pour l'import de recettes anglophones ?
- Faut-il un groupe « Annuel » distinct, ou une simple vue mois sur un groupe « Semaine » suffit-elle ?
- Monétisation future (gratuit, don, premium) — impacte peu la v1.
