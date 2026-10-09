-- Executar no SQL Editor do mesmo projeto Supabase das tarefas.
-- Reutiliza a identidade e o gestor já definidos em dm_shared_identity().
BEGIN;
ALTER TABLE public.dm_shared_tasks ENABLE ROW LEVEL SECURITY;
GRANT INSERT ON public.dm_shared_tasks TO authenticated;
DROP POLICY IF EXISTS dm_tasks_create_self ON public.dm_shared_tasks;
DROP POLICY IF EXISTS dm_tasks_assignment_guard ON public.dm_shared_tasks;
CREATE POLICY dm_tasks_create_self ON public.dm_shared_tasks
AS PERMISSIVE FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.dm_shared_identity() AS me
  WHERE me.enabled AND me.id = auth.uid()
    AND (me.id = me.owner_id OR assignee = me.id)
));
-- A política restritiva impede que outras políticas INSERT permissivas
-- permitam atribuir tarefas a terceiros.
CREATE POLICY dm_tasks_assignment_guard ON public.dm_shared_tasks
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.dm_shared_identity() AS me
  WHERE me.enabled AND me.id = auth.uid()
    AND (me.id = me.owner_id OR assignee = me.id)
));
DROP POLICY IF EXISTS dm_tasks_update_manager_guard ON public.dm_shared_tasks;
CREATE POLICY dm_tasks_update_manager_guard ON public.dm_shared_tasks
AS RESTRICTIVE FOR UPDATE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.dm_shared_identity() AS me
  WHERE me.enabled AND me.id = auth.uid() AND me.id = me.owner_id
))
WITH CHECK (EXISTS (
  SELECT 1 FROM public.dm_shared_identity() AS me
  WHERE me.enabled AND me.id = auth.uid() AND me.id = me.owner_id
));
COMMIT;
