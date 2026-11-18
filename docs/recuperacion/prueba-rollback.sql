-- Prueba de crm_intentar_recuperacion con rollback automático (la excepción final deshace todo).
-- Resultado esperado (18-nov-2026): anon/authenticated bloqueados en función y tabla; colaborador 'ok' (también con mayúsculas y espacios);
-- no colaborador/vacío/sin arroba 'no_existe'; límite por aparato: 3 intentos y el 4.º 'limite'; límite por correo: 3 envíos y el 4.º 'limite';
-- 0 datos en claro guardados.
do $$
declare r text := ''; em text; i int;
begin
  select email into em from public.profiles where role = 'admin' limit 1;
  begin set local role anon; perform public.crm_intentar_recuperacion(em, '1.1.1.1'); r := r || 'anon llama funcion: SI PUDO (MAL); ';
  exception when insufficient_privilege then r := r || 'anon llama funcion: bloqueado (bien); '; end;
  reset role;
  begin set local role authenticated; perform public.crm_intentar_recuperacion(em, '1.1.1.1'); r := r || 'authenticated llama funcion: SI PUDO (MAL); ';
  exception when insufficient_privilege then r := r || 'authenticated llama funcion: bloqueado (bien); '; end;
  reset role;
  set local role service_role;
  r := r || '| colaborador: ' || public.crm_intentar_recuperacion(em, '2.2.2.2');
  r := r || ' | con mayusculas y espacios: ' || public.crm_intentar_recuperacion('  ' || upper(em) || ' ', '3.3.3.3');
  r := r || ' | no colaborador: ' || public.crm_intentar_recuperacion('nadie@example.com', '4.4.4.4');
  r := r || ' | limite por aparato:';
  for i in 1..4 loop r := r || ' ' || i || '=' || public.crm_intentar_recuperacion('x' || i || '@example.com', '6.6.6.6'); end loop;
  r := r || ' | limite por correo:';
  for i in 1..2 loop r := r || ' ' || i || '=' || public.crm_intentar_recuperacion(em, '7.7.' || i || '.1'); end loop;
  r := r || ' | datos en claro: ' || (select count(*) from public.crm_recuperacion_intentos where ip_hash like '%.%' or email_hash like '%@%');
  reset role;
  raise exception 'RESULTADO: %', r;
end $$;
