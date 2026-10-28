# Publier Popote : écran de consentement Google et stores

Ce guide complète `README.md`. Les points marqués **(à vérifier)** dépendent de règles qui changent : relisez la page officielle au moment de faire la démarche.

## 1. Passer l'écran de consentement Google en production

Aujourd'hui l'écran est en mode **Test** : seuls les comptes listés dans « Utilisateurs test » (100 maximum) peuvent se connecter. Pour ouvrir l'appli à tout le monde, il faut la publier.

### Ce qu'il faut avoir avant

| Élément | Détail |
|---|---|
| Un nom de domaine à vous | La page d'accueil et la politique de confidentialité doivent être sur un domaine que vous possédez et vérifiez dans [Google Search Console](https://search.google.com/search-console). Un domaine de type `github.io` n'est généralement pas accepté comme « domaine autorisé » **(à vérifier)**. Un `.fr` ou `.app` coûte une dizaine d'euros par an. |
| Une page d'accueil | Une page simple qui décrit Popote et renvoie vers la politique de confidentialité. |
| La politique de confidentialité en ligne | `docs/privacy-policy.html` : complétez les passages entre crochets (éditeur, e-mail, date, région Supabase, durée des journaux), puis publiez-la. |
| Un logo | `docs/google-consent-logo-120.png` (120 × 120 px). |
| Un e-mail d'assistance | Affiché aux utilisateurs sur l'écran de consentement. |

### Héberger les pages (gratuit)

1. Poussez le dossier `docs/` sur GitHub.
2. GitHub > dépôt > **Settings** > **Pages** > Source : branche `main`, dossier `/docs`.
3. Ajoutez votre domaine dans **Custom domain** et créez l'enregistrement DNS indiqué par GitHub.
4. Vérifiez le domaine dans Google Search Console (enregistrement DNS de type TXT).
5. Créez `docs/index.html` (page d'accueil) : un titre, une phrase, un lien vers `privacy-policy.html`.

### Dans Google Cloud (projet `Popote`)

1. **Google Auth Platform** > **Branding** : nom `Popote`, e-mail d'assistance, logo, page d'accueil, lien de la politique de confidentialité, **domaines autorisés** (votre domaine), e-mail de contact du développeur.
2. **Accès aux données** : ne gardez que les portées de base `openid`, `.../auth/userinfo.email` et `.../auth/userinfo.profile`. N'en ajoutez aucune autre : ce sont des portées non sensibles, qui ne déclenchent pas la revue approfondie.
3. **Audience** > **Publier l'application** > confirmer. L'état passe de « Test » à « En production ».
4. **Centre de validation** : si Google demande une **vérification de la marque** (fréquent dès que vous affichez un logo ou un nom), suivez les étapes. Comptez quelques jours. Tant qu'elle n'est pas faite, la connexion marche, mais l'écran de consentement peut apparaître sans logo, avec un avertissement « application non validée » **(à vérifier)**.

### Dans Supabase (avant l'ouverture au public)

1. **Authentication** > **URL Configuration** : mettez en « Site URL » l'adresse publique de l'appli web si vous en publiez une, et gardez `app.popote://login-callback` dans les « Redirect URLs ».
2. Retirez `http://localhost:**` des redirections une fois en production.
3. Un projet gratuit est **mis en pause après 1 semaine sans activité**. Pour une appli publique, passez le projet en plan Pro (payant) avant le lancement.

## 2. Ce que demandent les stores

| | Google Play | App Store (Apple) |
|---|---|---|
| Compte développeur | Environ 25 $ une fois | Environ 99 $ par an |
| Politique de confidentialité | Lien obligatoire | Lien obligatoire |
| Suppression de compte | Obligatoire dans l'appli **et** décrite sur une page web (la section 6 de la politique suffit) | Obligatoire dans l'appli (Profil > Supprimer mon compte) |
| Déclaration des données | Formulaire « Sécurité des données » : nom, e-mail, contenu créé par l'utilisateur ; aucune donnée vendue ni partagée à des fins publicitaires | « Étiquettes de confidentialité » : même contenu |
| À vérifier | Un compte personnel récent peut devoir mener un test fermé avec un minimum de testeurs avant la production | Les apps qui proposent une connexion tierce (Google) doivent aussi proposer une connexion équivalente respectueuse de la vie privée, par exemple « Se connecter avec Apple » (règle 4.8) |

## 3. Avant de soumettre : à faire dans le code

- [ ] Identifiant d'application définitif : `app.popote` est utilisé comme préfixe ; vérifiez-le dans `android/app/build.gradle*` (applicationId) et Xcode (Bundle Identifier).
- [ ] `dart run flutter_launcher_icons` pour appliquer l'icône (voir `pubspec.yaml`).
- [ ] Exécuter `supabase/migrations/0003_delete_account.sql` : sans lui, « Supprimer mon compte » n'efface rien côté serveur.
- [ ] Embarquer les polices dans l'appli plutôt que les charger depuis Google Fonts (confidentialité et mode hors ligne) ; sinon gardez la mention dans la politique.
- [ ] Signature de l'appli Android (keystore) et profil de distribution iOS.
