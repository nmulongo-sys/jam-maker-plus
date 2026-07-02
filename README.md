# Jam Maker +

Outil collaboratif pour collectifs de musiciens : répertoire de chansons, compétences des membres, projets de morceaux avec répétitions et complétude, événements avec playlist calculée automatiquement, et génération du cahier de jam PDF de chaque participant.

**En ligne** : https://nmulongo-sys.github.io/jam-maker-plus/ (mode démo immédiat), ou ouvrir `index.html` dans un navigateur.
**Statut** : v0.2 (mode guidé, badges, conseils, dépôt PDF, aide) • fichier HTML unique • backend Supabase optionnel • pdf-lib via CDN.

## Le concept

Le cœur du modèle est le **triplet Personne × Chanson × Instrument** avec un statut (*en apprentissage / jouable / maîtrisé*). Tout en découle :

- les **badges** d'un membre (guitariste, bassiste…) sont l'agrégat de ses triplets par instrument ;
- un **projet** = une chanson à monter, avec des *slots* (besoins instrumentaux *indispensable / souhaitable / bonus*) pourvus par invitation ;
- la **complétude** d'un projet = % de slots indispensables dont le titulaire a confirmé « ça tient » après répétition ;
- la **playlist potentielle** d'un événement se calcule d'après les participants confirmés : un morceau est *jouable (équipe d'origine)*, *jouable avec doublure* (un présent qui a le triplet couvre un slot dont le titulaire est absent), ou *non jouable* ;
- le **cahier de jam** de chaque participant = PDF « page de garde + ses partitions dans l'ordre de la setlist cochée ».

### Règles métier

- 1 projet = 1 chanson. Un événement agrège plusieurs projets.
- Compétences auto-déclarées, mais confirmées par la pratique : un verdict « ça tient » en répétition fait passer le triplet du membre à « jouable ».
- Tout le monde peut créer chansons, projets et événements. Seul l'organisateur d'un événement coche la playlist finale et l'ordre.
- Cycle de vie d'un projet (dérivé, non stocké sauf « joué ») : brouillon → recrutement → en répétition → jouable → joué.

## Utilisation

**Pour les non-initiés** : le bouton **✨ Guidé** (en haut) ouvre un questionnaire pas à pas — qui es-tu, que sais-tu faire, que veux-tu (monter / rejoindre / organiser), avec qui, quand — qui crée tout à votre place. Il s'ouvre automatiquement à la première visite. L'onglet **Aide ?** contient le mode d'emploi complet en langage simple.

**Mode démo (zéro installation)** : ouvrir `index.html`. Les données (4 membres, 2 chansons, 1 projet, 1 événement) vivent dans le `localStorage` du navigateur. Le sélecteur en haut à droite permet de « se connecter » comme n'importe quel membre pour tester invitations et verdicts.

**Mode réel (Supabase)** :

1. Créer un projet gratuit sur [supabase.com](https://supabase.com).
2. Dans l'éditeur SQL, exécuter `schema.sql`.
3. Dans Storage, créer un bucket privé `partitions` avec policies lecture/écriture pour `authenticated`.
4. Dans `index.html`, renseigner `CONFIG.SUPABASE_URL` et `CONFIG.SUPABASE_ANON_KEY` (Settings → API).
5. Déployer sur GitHub Pages (Settings → Pages → branche main). La connexion se fait par lien magique email (Supabase Auth) ; ajouter l'URL Pages dans Authentication → URL Configuration.

## Architecture & conventions

- **Fichier unique** `index.html` : CSS → HTML (header + `<main id="app">`) → JS en blocs : `CONFIG` et données de démo ; icônes/badges ; couche données ; logique métier + conseils ; rendu + mode guidé + partitions + aide ; actions ; cahier PDF.
- **Couche données** : deux implémentations de la même interface (`load`, `insert`, `update`, `remove`, `uploadPartition`, `dataPartition`). `DemoAPI` persiste tout dans `localStorage` clé `jammaker.demo.v2` (membre courant : `jammaker.demo.user` ; mode guidé vu : `jammaker.guide.vu` ; partitions en dataURL, limitées à 2 Mo). `SupaAPI` charge supabase-js à la volée et réplique les tables dans le cache mémoire `S`.
- **État** : `S` = cache de toutes les tables (mêmes noms que `schema.sql`), `USER` = membre connecté, `GUIDE` = état du questionnaire guidé (étape, but, sélections), `FICHIERS_EN_ATTENTE` = PDF déposés pas encore rangés. Chaque action mute via l'API puis appelle `rafraichir()`.
- **Routage** : hash (`#/moi`, `#/repertoire`, `#/projets`, `#/projet/:id`, `#/evenements`, `#/evenement/:id`, `#/membres`, `#/partitions`, `#/guide`, `#/aide`), une fonction `vueX()` par écran. Première visite (clé `jammaker.guide.vu` absente) → redirection vers `#/guide`.
- **Icônes & badges** : `ICONES` (tracés SVG 24×24, style trait), `TEINTES` (couleur par instrument), `ARTICLE` (article partitif pour les phrases « joue de la guitare ») ; helpers `icone(instr,taille)` et `badgeInstr(instr,{gros})`.
- **Fonctions métier clés** : `completude(projet)`, `statutDerive(projet)`, `jouabilite(evenementId, projet)` (trois teintes + doublures suggérées), `saitJouer(membre, chanson, instrument)`, `candidats(projet, instrument)`.
- **Conseils contextualisés** : `conseilsProjet(p)` (qui inviter sur les slots vacants, bouton Inviter direct), `conseilsPourMoi()` (projets qui cherchent mes instruments), `conseilsEvenement(id)` (quelle présence débloquerait un morceau) ; rendu commun `carteConseils(liste, bouton)`.
- **Mode guidé** : machine à étapes dans `vueGuide()` (1 identité → 2 compétences → 3 intention → 4-6 selon le but → 7 récapitulatif → fin) ; `guideTerminer()` crée chansons/projets/slots/invitations/répétitions ou événement+participation via l'API standard.
- **Dépôt PDF** : écran `#/partitions` avec glisser-déposer multi-fichiers ; `devinerCible(nom)` pré-remplit projet et instrument d'après le nom du fichier (ex. `hotel-california-basse.pdf`).
- **Cahier PDF** : `genererCahier(evtId, membreId)` avec [pdf-lib](https://pdf-lib.js.org) (CDN) — page de garde A4 (setlist annotée tonalité/tempo/instrument du membre) puis fusion des PDF de partitions (dernière version par instrument), page finale listant les partitions manquantes.
- **Convention compétences** : dans la table `competences`, `chanson_id NULL` = badge général d'instrument ; `chanson_id` renseigné = morceau acquis (ex. « Hotel California – guitare »).
- **Sécurité (v0.2)** : RLS « communauté de confiance » — lecture pour tous les authentifiés, écriture sur ses propres données ; le créateur d'un projet gère slots et répétitions, l'organisateur d'un événement gère la playlist.

## Feuille de route

- **v1 (en cours)** : tout ce qui est décrit ci-dessus.
- **v2 (envisagé)** : sondage de dates pour les répétitions, notifications email (Supabase Edge Functions), annotations et versionnage avancé des partitions, mode « jam ouverte » le jour J (un invité déclare une compétence sur place → morceaux bonus), statistiques du collectif.

### Inspirations

Aucun projet open source existant ne couvre le modèle compétences → invitations → complétude → playlist automatique. Pour la génération de setlists PDF, voir [laenzlinger/setlist](https://github.com/laenzlinger/setlist) ; pour la gestion simple de setlists, [Setlist-Planner](https://github.com/PieterCooreman/Setlist-Planner).

## Journal de développement

### 2026-07-02 — v0.2 : accessibilité aux non-initiés
- **Mode guidé** (`#/guide`) : questionnaire pas à pas — qui es-tu / que sais-tu faire / que veux-tu (monter un morceau, rejoindre, organiser une jam) / avec qui / quand — qui crée les objets à la place de l'utilisateur ; s'ouvre automatiquement à la première visite (clé `jammaker.guide.vu`), bouton ✨ permanent dans la barre.
- **Icônes et vrais badges d'instruments** : pictos SVG dessinés au trait, pastille colorée par instrument (`ICONES`, `TEINTES`, `badgeInstr`), utilisés partout (Ma page, projets, événements, membres, partitions).
- **Conseils contextualisés** : « Jean joue de la guitare et connaît déjà ce morceau — la recrue idéale » sur les projets (avec bouton Inviter), « il manque quelqu'un à la basse sur X — et tu joues de la basse ! » sur Ma page, « si Marc confirme sa présence, X devient jouable » sur les événements.
- **Outil de dépôt des PDF** (`#/partitions`) : glisser-déposer multi-fichiers, pré-classement automatique d'après le nom du fichier, vue d'ensemble de toutes les partitions du groupe.
- **Mode d'emploi intégré** (`#/aide`) : pas-à-pas en langage simple + lexique, pensé pour des utilisateurs peu à l'aise en informatique.
- Données de démo enrichies (slot batterie vacant pour illustrer les conseils), clé de démo passée à `jammaker.demo.v2`.

### 2026-07-02 — révision initiale (ossature v0.1)
- Conception du modèle : triplet Personne × Chanson × Instrument, slots pondérés, complétude par verdicts de répétition, jouabilité en trois teintes (origine / doublure / non jouable) recalculée par événement.
- Décisions actées : 1 projet = 1 chanson ; auto-déclaration + confirmation en répète ; création ouverte à tous ; architecture HTML autonome + Supabase ; cahier de jam = un PDF assemblé par personne.
- Livré : `index.html` (mode démo localStorage + branchement Supabase, 6 écrans, calculs métier, génération du cahier via pdf-lib), `schema.sql` (11 tables, types énumérés, RLS), ce README.

## Contributions

Issues bienvenues pour signaler un bug ou proposer une idée ; pull requests relues au cas par cas.

## Licence

MIT — réutilisation libre, l'auteur reste crédité (voir `LICENSE`).
