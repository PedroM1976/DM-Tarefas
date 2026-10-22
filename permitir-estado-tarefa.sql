begin;

create or replace function public.dm_shared_set_task_status(
  p_task_id uuid,
  p_new_status text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_task public.dm_shared_tasks%rowtype;
  v_completed_at text;
begin
  if p_new_status not in ('todo', 'doing', 'waiting', 'done') then
    raise exception 'Estado inválido.';
  end if;

  select *
    into v_task
    from public.dm_shared_tasks
   where id = p_task_id
   for update;

  if not found then
    raise exception 'Tarefa não encontrada.';
  end if;

  if not exists (
    select 1
      from public.dm_shared_users u
     where u.id = auth.uid()
       and u.enabled
       and (
         u.id = (
           select o.user_id
             from public.dm_shared_owner o
            where o.singleton = true
         )
         or lower(trim(u.display_name)) = 'filipe freitas'
         or v_task.assignee = auth.uid()
       )
  ) then
    raise exception 'Não tens permissão para alterar esta tarefa.';
  end if;

  v_completed_at :=
    case
      when p_new_status = 'done'
        then coalesce(
          nullif(v_task.payload ->> 'completedAt', ''),
          current_date::text
        )
      else ''
    end;

  update public.dm_shared_tasks
     set payload = jsonb_set(
       jsonb_set(
         jsonb_set(
           v_task.payload,
           '{status}',
           to_jsonb(p_new_status),
           true
         ),
         '{progress}',
         to_jsonb(
           case when p_new_status = 'done' then 100 else 0 end
         ),
         true
       ),
       '{completedAt}',
       to_jsonb(v_completed_at),
       true
     )
   where id = p_task_id
   returning payload into v_task.payload;

  return v_task.payload;
end;
$$;

revoke all
on function public.dm_shared_set_task_status(uuid, text)
from public, anon;

grant execute
on function public.dm_shared_set_task_status(uuid, text)
to authenticated;

commit;
