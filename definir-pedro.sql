-- Executar depois de criar a conta de Pedro em Authentication > Users.
-- Substituir pelo email real da conta Pedro Morgado.
do $$
declare pedro uuid;
begin
 select id into pedro from auth.users where lower(email)=lower('COLOCAR_EMAIL_PEDRO');
 if pedro is null then raise exception 'Cria primeiro a conta de Pedro e substitui o email neste SQL.'; end if;
 update public.dm_shared_users set display_name='Pedro Morgado',enabled=true where id=pedro;
 insert into public.dm_shared_owner(singleton,user_id) values(true,pedro)
 on conflict(singleton) do update set user_id=excluded.user_id;
end $$;
