begin;
create table if not exists public.dm_shared_users (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(length(display_name) between 1 and 200),
 enabled boolean not null default false
);
create table if not exists public.dm_shared_owner (
 singleton boolean primary key default true check(singleton),
 user_id uuid not null unique references public.dm_shared_users(id)
);
create table if not exists public.dm_shared_tasks (
 id uuid primary key,
 assignee uuid not null references public.dm_shared_users(id),
 payload jsonb not null check(jsonb_typeof(payload)='object')
 check(length(payload->>'title') between 1 and 200)
 check(payload->>'status' in ('todo','doing','waiting','done'))
 check(payload->>'priority' in ('high','normal','low')),
 created_at timestamptz not null default now()
);
create or replace function public.dm_shared_is_owner() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.dm_shared_owner o join public.dm_shared_users u on u.id=o.user_id where o.user_id=auth.uid() and u.enabled);
$$;
create or replace function public.dm_shared_is_enabled() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.dm_shared_users where id=auth.uid() and enabled);
$$;
create or replace function public.dm_shared_identity() returns table(id uuid,display_name text,enabled boolean,owner_id uuid)
language sql stable security definer set search_path='' as $$
 select u.id,u.display_name,u.enabled,(select user_id from public.dm_shared_owner) from public.dm_shared_users u where u.id=auth.uid();
$$;
create or replace function public.dm_shared_new_user() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into public.dm_shared_users(id,display_name) values(new.id,coalesce(nullif(new.raw_user_meta_data->>'display_name',''),new.email,new.id::text)) on conflict(id) do nothing;
 return new;
end;$$;
drop trigger if exists dm_shared_auth_user on auth.users;
create trigger dm_shared_auth_user after insert on auth.users for each row execute function public.dm_shared_new_user();
insert into public.dm_shared_users(id,display_name)
 select id,coalesce(nullif(raw_user_meta_data->>'display_name',''),email,id::text) from auth.users on conflict(id) do nothing;
alter table public.dm_shared_users enable row level security;
alter table public.dm_shared_owner enable row level security;
alter table public.dm_shared_tasks enable row level security;
revoke all on public.dm_shared_users,public.dm_shared_owner,public.dm_shared_tasks from anon,authenticated;
grant select on public.dm_shared_users to authenticated;
grant update(enabled) on public.dm_shared_users to authenticated;
grant select,insert,update,delete on public.dm_shared_tasks to authenticated;
drop policy if exists dm_shared_user_read on public.dm_shared_users;
create policy dm_shared_user_read on public.dm_shared_users for select to authenticated using(id=auth.uid() or public.dm_shared_is_owner());
drop policy if exists dm_shared_user_edit on public.dm_shared_users;
create policy dm_shared_user_edit on public.dm_shared_users for update to authenticated using(public.dm_shared_is_owner()) with check(public.dm_shared_is_owner());
drop policy if exists dm_shared_task_read on public.dm_shared_tasks;
create policy dm_shared_task_read on public.dm_shared_tasks for select to authenticated using(public.dm_shared_is_enabled() and (public.dm_shared_is_owner() or assignee=auth.uid()));
drop policy if exists dm_shared_task_add on public.dm_shared_tasks;
create policy dm_shared_task_add on public.dm_shared_tasks for insert to authenticated with check(public.dm_shared_is_owner());
drop policy if exists dm_shared_task_edit on public.dm_shared_tasks;
create policy dm_shared_task_edit on public.dm_shared_tasks for update to authenticated using(public.dm_shared_is_owner()) with check(public.dm_shared_is_owner());
drop policy if exists dm_shared_task_delete on public.dm_shared_tasks;
create policy dm_shared_task_delete on public.dm_shared_tasks for delete to authenticated using(public.dm_shared_is_owner());
revoke all on function public.dm_shared_identity(),public.dm_shared_is_owner(),public.dm_shared_is_enabled(),public.dm_shared_new_user() from public,anon;
grant execute on function public.dm_shared_identity(),public.dm_shared_is_owner(),public.dm_shared_is_enabled() to authenticated;
commit;
