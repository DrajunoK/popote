-- Suppression de compte (exigée par l'App Store et Google Play).
-- Quitte tous les groupes partagés (le dernier admin est remplacé, un groupe sans membre disparaît),
-- supprime les espaces personnels puis le compte et le profil.
-- À coller dans Supabase > SQL Editor > Run.

create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_group record;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Espaces personnels : supprimés avec leur contenu.
  delete from public.groups g
  where g.personal
    and exists (select 1 from public.group_members m where m.group_id = g.id and m.user_id = v_uid);

  -- Groupes partagés : on les quitte comme avec leave_group.
  for v_group in
    select m.group_id from public.group_members m where m.user_id = v_uid
  loop
    perform public.leave_group(v_group.group_id);
  end loop;

  -- Profil puis compte (le profil et les adhésions restantes partent en cascade).
  delete from auth.users where id = v_uid;
end;
$$;

revoke execute on function public.delete_account() from public, anon;
grant execute on function public.delete_account() to authenticated;
