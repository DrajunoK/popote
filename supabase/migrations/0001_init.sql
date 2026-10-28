-- Popote : groupes, membres, invitations et documents synchronisés.
-- À coller dans Supabase > SQL Editor > Run.
--
-- Modèle : tout ce qui est partagé (recettes, repas planifiés, articles de courses…) est stocké
-- comme un « document » JSON dans `docs`, rattaché à un groupe. Le dernier écrit gagne
-- (horodatage serveur). La sécurité (RLS) repose sur l'appartenance au groupe.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '',
  email text
);

create table if not exists public.groups (
  id text primary key,
  name text not null,
  color bigint not null,
  personal boolean not null default false,
  settings jsonb not null default '{}'::jsonb,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id text not null references public.groups (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member',
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table if not exists public.docs (
  group_id text not null references public.groups (id) on delete cascade,
  kind text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  deleted boolean not null default false,
  updated_at timestamptz not null default clock_timestamp(),
  primary key (group_id, kind, id)
);

create index if not exists docs_updated_at_idx on public.docs (updated_at);

create table if not exists public.invites (
  code text primary key,
  group_id text not null references public.groups (id) on delete cascade,
  created_by uuid default auth.uid(),
  expires_at timestamptz not null
);

-- ---------------------------------------------------------------------------
-- Profil créé automatiquement à l'inscription
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1), ''),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Comptes créés avant ce script.
insert into public.profiles (id, name, email)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', split_part(u.email, '@', 1), ''),
       u.email
from auth.users u
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Fonctions utilitaires (security definer : évitent la récursion des policies)
-- ---------------------------------------------------------------------------

create or replace function public.is_member(gid text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

create or replace function public.is_admin(gid text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.touch_doc()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end;
$$;

drop trigger if exists docs_touch on public.docs;
create trigger docs_touch
  before insert or update on public.docs
  for each row execute function public.touch_doc();

-- ---------------------------------------------------------------------------
-- RPC : créer un groupe, inviter, rejoindre
-- ---------------------------------------------------------------------------

-- Idempotent : rappelée avec le même id par son propriétaire, ne fait rien.
create or replace function public.create_group(
  p_id text,
  p_name text,
  p_color bigint,
  p_personal boolean,
  p_settings jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  if exists (select 1 from public.groups where id = p_id) then
    if not public.is_member(p_id) then
      raise exception 'group id already used';
    end if;
    return;
  end if;

  insert into public.groups (id, name, color, personal, settings, created_by)
  values (p_id, p_name, p_color, p_personal, coalesce(p_settings, '{}'::jsonb), auth.uid());

  insert into public.group_members (group_id, user_id, role)
  values (p_id, auth.uid(), 'admin');
end;
$$;

create or replace function public.create_invite(p_group_id text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if not public.is_member(p_group_id) then
    raise exception 'not a member';
  end if;
  if exists (select 1 from public.groups where id = p_group_id and personal) then
    raise exception 'personal group';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8));
  insert into public.invites (code, group_id, expires_at)
  values (v_code, p_group_id, now() + interval '7 days');
  return v_code;
end;
$$;

create or replace function public.join_group(p_code text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select group_id into v_group
  from public.invites
  where code = upper(trim(p_code)) and expires_at > now();

  if v_group is null then
    raise exception 'invalid or expired code';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group, auth.uid(), 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group;
end;
$$;

revoke execute on function public.create_group(text, text, bigint, boolean, jsonb) from public, anon;
revoke execute on function public.create_invite(text) from public, anon;
revoke execute on function public.join_group(text) from public, anon;
grant execute on function public.create_group(text, text, bigint, boolean, jsonb) to authenticated;
grant execute on function public.create_invite(text) to authenticated;
grant execute on function public.join_group(text) to authenticated;
grant execute on function public.is_member(text) to authenticated;
grant execute on function public.is_admin(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Droits et sécurité par ligne (RLS)
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.docs enable row level security;
alter table public.invites enable row level security;

grant select, update on public.profiles to authenticated;
grant select, update, delete on public.groups to authenticated;
grant select, update, delete on public.group_members to authenticated;
grant select, insert, update, delete on public.docs to authenticated;
-- `invites` : aucun accès direct, uniquement via les RPC.

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1
      from public.group_members mine
      join public.group_members theirs on theirs.group_id = mine.group_id
      where mine.user_id = auth.uid() and theirs.user_id = profiles.id
    )
  );

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists groups_select on public.groups;
create policy groups_select on public.groups for select to authenticated
  using (public.is_member(id));

drop policy if exists groups_update on public.groups;
create policy groups_update on public.groups for update to authenticated
  using (public.is_admin(id)) with check (public.is_admin(id));

drop policy if exists groups_delete on public.groups;
create policy groups_delete on public.groups for delete to authenticated
  using (public.is_admin(id));

drop policy if exists members_select on public.group_members;
create policy members_select on public.group_members for select to authenticated
  using (public.is_member(group_id));

drop policy if exists members_update on public.group_members;
create policy members_update on public.group_members for update to authenticated
  using (public.is_admin(group_id)) with check (public.is_admin(group_id));

-- On peut quitter un groupe ; un admin peut retirer un membre.
drop policy if exists members_delete on public.group_members;
create policy members_delete on public.group_members for delete to authenticated
  using (user_id = auth.uid() or public.is_admin(group_id));

drop policy if exists docs_all on public.docs;
create policy docs_all on public.docs for all to authenticated
  using (public.is_member(group_id)) with check (public.is_member(group_id));

-- ---------------------------------------------------------------------------
-- Temps réel
-- ---------------------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.group_members;
exception when duplicate_object then null;
end $$;
