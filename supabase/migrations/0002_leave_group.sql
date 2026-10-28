-- Quitter un groupe. Si c'était le dernier membre, le groupe est supprimé ;
-- si c'était le dernier admin, le membre le plus ancien devient admin.
-- À coller dans Supabase > SQL Editor > Run.

create or replace function public.leave_group(p_group_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from public.groups where id = p_group_id and personal) then
    raise exception 'personal group';
  end if;

  delete from public.group_members
  where group_id = p_group_id and user_id = auth.uid();

  if not exists (select 1 from public.group_members where group_id = p_group_id) then
    delete from public.groups where id = p_group_id;
    return;
  end if;

  if not exists (select 1 from public.group_members where group_id = p_group_id and role = 'admin') then
    update public.group_members
    set role = 'admin'
    where group_id = p_group_id
      and user_id = (
        select user_id from public.group_members
        where group_id = p_group_id
        order by joined_at
        limit 1
      );
  end if;
end;
$$;

revoke execute on function public.leave_group(text) from public, anon;
grant execute on function public.leave_group(text) to authenticated;
