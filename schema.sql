-- ============================================================
-- Jam Maker + — schéma Supabase (PostgreSQL)
-- À exécuter dans l'éditeur SQL de votre projet Supabase.
-- Version : 0.1 (2026-07-02)
-- ============================================================

-- ---------- Types énumérés ----------

create type statut_competence as enum ('apprentissage', 'jouable', 'maitrise');
create type statut_projet     as enum ('brouillon', 'recrutement', 'repetition', 'jouable', 'joue');
create type niveau_besoin     as enum ('indispensable', 'souhaitable', 'bonus');
create type statut_invitation as enum ('en_attente', 'accepte', 'refuse');
create type verdict_repet     as enum ('ca_tient', 'a_retravailler');
create type statut_presence   as enum ('confirme', 'peut_etre', 'absent');

-- ---------- Tables ----------

-- Profil public de chaque membre (lié au compte auth Supabase)
create table membres (
  id         uuid primary key references auth.users(id) on delete cascade,
  pseudo     text not null unique,
  cree_le    timestamptz not null default now()
);

-- Répertoire des chansons
create table chansons (
  id              uuid primary key default gen_random_uuid(),
  titre           text not null,
  artiste         text,
  tonalite        text,            -- ex. 'Bm', 'Eb'
  tempo           int,             -- BPM
  structure       text,            -- ex. 'intro / couplet x2 / pont / final'
  lien_reference  text,            -- URL YouTube/Spotify de la version de travail
  cree_par        uuid references membres(id),
  cree_le         timestamptz not null default now()
);

-- LE TRIPLET Personne × Chanson × Instrument.
-- chanson_id NULL = badge général (ex. « bassiste »).
-- chanson_id renseigné = compétence acquise (ex. « Hotel California – guitare »).
create table competences (
  id          uuid primary key default gen_random_uuid(),
  membre_id   uuid not null references membres(id) on delete cascade,
  chanson_id  uuid references chansons(id) on delete cascade,
  instrument  text not null,       -- ex. 'guitare', 'basse', 'chant', 'batterie'
  statut      statut_competence not null default 'apprentissage',
  maj_le      timestamptz not null default now(),
  unique (membre_id, chanson_id, instrument)
);

-- Un projet = UNE chanson montée par un groupe de slots
create table projets (
  id          uuid primary key default gen_random_uuid(),
  chanson_id  uuid not null references chansons(id),
  statut      statut_projet not null default 'brouillon',
  cree_par    uuid references membres(id),
  cree_le     timestamptz not null default now()
);

-- Un slot = un besoin instrumental du projet, pourvu ou non.
-- membre_id NULL + statut_invitation NULL = poste ouvert.
-- membre_id renseigné + 'en_attente' = invitation envoyée (visible sur « Ma page »).
create table slots (
  id          uuid primary key default gen_random_uuid(),
  projet_id   uuid not null references projets(id) on delete cascade,
  instrument  text not null,
  besoin      niveau_besoin not null default 'indispensable',
  membre_id   uuid references membres(id) on delete set null,
  invitation  statut_invitation,
  cree_le     timestamptz not null default now()
);

-- Partitions déposées par slot/instrument (fichiers dans le bucket 'partitions')
create table partitions (
  id           uuid primary key default gen_random_uuid(),
  projet_id    uuid not null references projets(id) on delete cascade,
  instrument   text not null,
  fichier      text not null,      -- chemin dans le bucket Storage 'partitions'
  version      int not null default 1,
  uploade_par  uuid references membres(id),
  uploade_le   timestamptz not null default now()
);

-- Répétitions planifiées d'un projet
create table repetitions (
  id         uuid primary key default gen_random_uuid(),
  projet_id  uuid not null references projets(id) on delete cascade,
  date       timestamptz not null,
  lieu       text,
  notes      text
);

-- Verdict de chaque participant après une répétition.
-- La complétude d'un projet = % de slots indispensables dont le DERNIER
-- verdict est 'ca_tient'. L'historique est conservé.
create table confirmations (
  id             uuid primary key default gen_random_uuid(),
  repetition_id  uuid not null references repetitions(id) on delete cascade,
  slot_id        uuid not null references slots(id) on delete cascade,
  verdict        verdict_repet not null,
  date           timestamptz not null default now(),
  unique (repetition_id, slot_id)
);

-- Événements (concerts, jams)
create table evenements (
  id        uuid primary key default gen_random_uuid(),
  nom       text not null,
  date      timestamptz not null,
  lieu      text,
  cree_par  uuid references membres(id),
  cree_le   timestamptz not null default now()
);

-- Qui vient à l'événement (base du calcul de jouabilité)
create table participations (
  id            uuid primary key default gen_random_uuid(),
  evenement_id  uuid not null references evenements(id) on delete cascade,
  membre_id     uuid not null references membres(id) on delete cascade,
  statut        statut_presence not null default 'confirme',
  unique (evenement_id, membre_id)
);

-- Playlist d'un événement : projets cochés par l'organisateur, ordonnés
create table playlist_items (
  id            uuid primary key default gen_random_uuid(),
  evenement_id  uuid not null references evenements(id) on delete cascade,
  projet_id     uuid not null references projets(id) on delete cascade,
  coche         boolean not null default false,
  ordre         int not null default 0,
  unique (evenement_id, projet_id)
);

-- ---------- Index utiles ----------

create index on competences (membre_id);
create index on competences (chanson_id, instrument);
create index on slots (projet_id);
create index on slots (membre_id) where membre_id is not null;
create index on confirmations (slot_id, date desc);
create index on playlist_items (evenement_id, ordre);

-- ---------- Sécurité (RLS) ----------
-- Philosophie v0.1 : communauté de confiance. Tout membre connecté lit tout ;
-- chacun ne modifie que ce qui lui appartient. À durcir si le collectif grandit.

alter table membres        enable row level security;
alter table chansons       enable row level security;
alter table competences    enable row level security;
alter table projets        enable row level security;
alter table slots          enable row level security;
alter table partitions     enable row level security;
alter table repetitions    enable row level security;
alter table confirmations  enable row level security;
alter table evenements     enable row level security;
alter table participations enable row level security;
alter table playlist_items enable row level security;

-- Lecture : tout utilisateur authentifié
create policy lecture_membres        on membres        for select to authenticated using (true);
create policy lecture_chansons       on chansons       for select to authenticated using (true);
create policy lecture_competences    on competences    for select to authenticated using (true);
create policy lecture_projets        on projets        for select to authenticated using (true);
create policy lecture_slots          on slots          for select to authenticated using (true);
create policy lecture_partitions     on partitions     for select to authenticated using (true);
create policy lecture_repetitions    on repetitions    for select to authenticated using (true);
create policy lecture_confirmations  on confirmations  for select to authenticated using (true);
create policy lecture_evenements     on evenements     for select to authenticated using (true);
create policy lecture_participations on participations for select to authenticated using (true);
create policy lecture_playlist       on playlist_items for select to authenticated using (true);

-- Écriture : son propre profil et ses propres compétences
create policy maj_profil on membres for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy maj_competences on competences for all to authenticated
  using (membre_id = auth.uid()) with check (membre_id = auth.uid());

-- Création ouverte (esprit jam : tout le monde peut créer chansons, projets, événements)
create policy creer_chansons   on chansons   for insert to authenticated with check (cree_par = auth.uid());
create policy creer_projets    on projets    for insert to authenticated with check (cree_par = auth.uid());
create policy creer_evenements on evenements for insert to authenticated with check (cree_par = auth.uid());

-- Le créateur d'un projet gère ses slots et répétitions
create policy gerer_slots on slots for all to authenticated
  using (exists (select 1 from projets p where p.id = projet_id and p.cree_par = auth.uid())
         or membre_id = auth.uid())
  with check (exists (select 1 from projets p where p.id = projet_id and p.cree_par = auth.uid())
              or membre_id = auth.uid());
create policy gerer_repetitions on repetitions for all to authenticated
  using (exists (select 1 from projets p where p.id = projet_id and p.cree_par = auth.uid()))
  with check (exists (select 1 from projets p where p.id = projet_id and p.cree_par = auth.uid()));
create policy maj_projet on projets for update to authenticated
  using (cree_par = auth.uid()) with check (cree_par = auth.uid());

-- Chacun dépose ses partitions et confirme ses propres slots
create policy deposer_partitions on partitions for insert to authenticated
  with check (uploade_par = auth.uid());
create policy confirmer on confirmations for insert to authenticated
  with check (exists (select 1 from slots s where s.id = slot_id and s.membre_id = auth.uid()));

-- Chacun gère sa participation ; l'organisateur gère la playlist
create policy gerer_participation on participations for all to authenticated
  using (membre_id = auth.uid()) with check (membre_id = auth.uid());
create policy gerer_playlist on playlist_items for all to authenticated
  using (exists (select 1 from evenements e where e.id = evenement_id and e.cree_par = auth.uid()))
  with check (exists (select 1 from evenements e where e.id = evenement_id and e.cree_par = auth.uid()));

-- ---------- Stockage ----------
-- Créer dans l'interface Supabase un bucket privé nommé 'partitions'
-- (Storage → New bucket), puis :
--   - policy de lecture pour 'authenticated'
--   - policy d'upload pour 'authenticated'
-- Les fichiers sont référencés par la colonne partitions.fichier.
