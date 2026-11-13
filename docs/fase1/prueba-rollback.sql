-- ============================================================================
-- Prueba de la Fase 1 (para correr DESPUÉS de aplicar propuesta.sql, p. ej. en una rama
-- de Supabase o ya en el ERP con el OK del Orquestador ERP).
--
-- No deja nada guardado: todo termina en un `raise exception`, que deshace la
-- transacción. El mensaje del error ES el resultado: busca "FALLAS: 0".
-- Usa usuarios reales que ya existen (administrador, cajero, tejedora) y simula su
-- sesión con request.jwt.claims. Si falta alguno de los tres, la prueba lo dice.
-- ============================================================================
do $$
declare
  v_admin   uuid;
  v_cajero  uuid;
  v_tejedora uuid;
  v_contacto uuid;
  r         text := '';
  fallas    int  := 0;
  n         int;
  v_tmp     bigint;

begin
  select user_id into v_admin   from public.usuarios_roles where rol::text = 'administrador' and activo limit 1;
  select user_id into v_cajero  from public.usuarios_roles where rol::text = 'cajero'        and activo limit 1;
  select t.user_id into v_tejedora from public.tejedoras_usuarios t
   where not exists (select 1 from public.usuarios_roles u where u.user_id = t.user_id and u.activo) limit 1;

  if v_admin is null then raise exception 'No hay un usuario administrador para probar'; end if;
  r := r || 'Usuarios de prueba: administrador=SI cajero=' || case when v_cajero is null then 'NO HAY' else 'SI' end
         || ' tejedora=' || case when v_tejedora is null then 'NO HAY' else 'SI' end || E'\n';

  -- Un contacto de prueba, creado como dueño de la base (se deshace al final)
  insert into public.crm_contactos (nombre, telefono) values ('PRUEBA ROLLBACK', '0000000000') returning id into v_contacto;

  -- ---------------------------------------------------------------- ADMINISTRADORA
  perform set_config('request.jwt.claims', json_build_object('sub', v_admin, 'role', 'authenticated')::text, true);
  set local role authenticated;

  select count(*) into n from public.crm_contactos where id = v_contacto;
  r := r || 'ADMIN ve el contacto: ' || n || ' (esperado 1)' || E'\n'; if n <> 1 then fallas := fallas + 1; end if;

  begin
    insert into public.crm_interacciones (contacto_id, tipo, resumen) values (v_contacto, 'nota', 'prueba');
    r := r || 'ADMIN crea interacción: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN crea interacción: NO (esperado SI) ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  begin
    insert into public.crm_interacciones (contacto_id, tercero_id, tipo) values (v_contacto, (select id from public.terceros limit 1), 'nota');
    r := r || 'ADMIN interacción con dos dueños: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
  exception when check_violation then r := r || 'ADMIN interacción con dos dueños: NO (esperado NO)' || E'\n';
            when others then r := r || 'ADMIN interacción con dos dueños: error distinto: ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  begin insert into public.crm_tareas (contacto_id, titulo) values (v_contacto, 'prueba'); r := r || 'ADMIN crea tarea: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN crea tarea: NO ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  select count(*) into n from public.crm_plantillas_mensaje;
  r := r || 'ADMIN ve plantillas: ' || n || ' (esperado 5 si se cargaron)' || E'\n'; if n < 5 then fallas := fallas + 1; end if;

  begin perform * from public.fn_crm_clientes_resumen(null); r := r || 'ADMIN fn_crm_clientes_resumen: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN fn_crm_clientes_resumen: NO ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  begin perform * from public.fn_crm_embudo(); r := r || 'ADMIN fn_crm_embudo: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN fn_crm_embudo: NO ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  begin perform * from public.fn_crm_historial_compras((select id from public.terceros limit 1)); r := r || 'ADMIN fn_crm_historial_compras: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN fn_crm_historial_compras: NO ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  begin perform * from public.fn_crm_casas_cliente(null); r := r || 'ADMIN fn_crm_casas_cliente: SI (esperado SI)' || E'\n';
  exception when others then r := r || 'ADMIN fn_crm_casas_cliente: NO ' || sqlerrm || E'\n'; fallas := fallas + 1; end;

  select count(*) into n from pg_proc p join pg_namespace sc on sc.oid = p.pronamespace
   where sc.nspname = 'public' and p.proname = 'fn_crm_casas_cliente'
     and pg_get_functiondef(p.oid) ~* '(pedidos_web|cuentas_clientes_web|p_incluir_web)';
  r := r || 'ADMIN fn_crm_casas_cliente menciona tablas de la web: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;

  select count(*) into n from public.fn_crm_casas_cliente(null) x where x.casa not in ('Crochet', 'Mercería', 'Academy', 'Agenda');
  r := r || 'ADMIN casas fuera de Crochet/Mercería/Academy/Agenda: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;

  -- Los clientes sin autorización de datos NO deben salir en el resumen
  select count(*) into n from public.fn_crm_clientes_resumen(null) x
    join public.terceros t on t.id = x.tercero_id where not t.acepta_tratamiento_datos;
  r := r || 'ADMIN resumen con clientes sin autorización: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;
  reset role;

  -- ---------------------------------------------------------------- CAJERO y TEJEDORA (no deben ver ni tocar nada)
  for i in 1..2 loop
    declare
      v_uid uuid := case i when 1 then v_cajero else v_tejedora end;
      v_nom text := case i when 1 then 'CAJERO' else 'TEJEDORA' end;
    begin
      if v_uid is null then r := r || v_nom || ': (no hay usuario para probar)' || E'\n'; continue; end if;
      perform set_config('request.jwt.claims', json_build_object('sub', v_uid, 'role', 'authenticated')::text, true);
      set local role authenticated;

      select (select count(*) from public.crm_contactos) + (select count(*) from public.crm_interacciones)
           + (select count(*) from public.crm_tareas) + (select count(*) from public.crm_fechas_especiales)
           + (select count(*) from public.crm_plantillas_mensaje) + (select count(*) from public.crm_oportunidades_detalle)
        into v_tmp;
      r := r || v_nom || ' filas visibles en tablas crm_: ' || v_tmp || ' (esperado 0)' || E'\n'; if v_tmp <> 0 then fallas := fallas + 1; end if;

      begin insert into public.crm_contactos (nombre) values ('intruso'); r := r || v_nom || ' crea contacto: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
      exception when others then r := r || v_nom || ' crea contacto: NO (esperado NO)' || E'\n'; end;

      begin perform * from public.fn_crm_clientes_resumen(null); r := r || v_nom || ' fn_crm_clientes_resumen: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
      exception when others then r := r || v_nom || ' fn_crm_clientes_resumen: NO (esperado NO)' || E'\n'; end;

      begin perform * from public.fn_crm_embudo(); r := r || v_nom || ' fn_crm_embudo: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
      exception when others then r := r || v_nom || ' fn_crm_embudo: NO (esperado NO)' || E'\n'; end;

      begin perform * from public.fn_crm_historial_compras((select id from public.terceros limit 1)); r := r || v_nom || ' fn_crm_historial_compras: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
      exception when others then r := r || v_nom || ' fn_crm_historial_compras: NO (esperado NO)' || E'\n'; end;

      begin perform * from public.fn_crm_casas_cliente(null); r := r || v_nom || ' fn_crm_casas_cliente: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
      exception when others then r := r || v_nom || ' fn_crm_casas_cliente: NO (esperado NO)' || E'\n'; end;
      reset role;
    end;
  end loop;

  -- ---------------------------------------------------------------- VISITANTE SIN SESIÓN
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  set local role anon;
  begin perform 1 from public.crm_contactos; r := r || 'ANON lee crm_contactos: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
  exception when insufficient_privilege then r := r || 'ANON lee crm_contactos: NO (esperado NO)' || E'\n'; end;
  begin perform * from public.fn_crm_clientes_resumen(null); r := r || 'ANON fn_crm_clientes_resumen: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
  exception when insufficient_privilege then r := r || 'ANON fn_crm_clientes_resumen: NO (esperado NO)' || E'\n'; end;
  begin perform * from public.fn_crm_embudo(); r := r || 'ANON fn_crm_embudo: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
  exception when insufficient_privilege then r := r || 'ANON fn_crm_embudo: NO (esperado NO)' || E'\n'; end;
  begin perform * from public.fn_crm_casas_cliente(null); r := r || 'ANON fn_crm_casas_cliente: SI (esperado NO)' || E'\n'; fallas := fallas + 1;
  exception when insufficient_privilege then r := r || 'ANON fn_crm_casas_cliente: NO (esperado NO)' || E'\n'; end;
  reset role;

  -- ---------------------------------------------------------------- Permisos de catálogo (nadie de afuera ejecuta nada interno)
  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.proname like 'fn\_crm\_%'
     and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('public', p.oid, 'execute'));
  r := r || 'Funciones fn_crm_* ejecutables por anon/PUBLIC: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;

  select count(*) into n from pg_proc p join pg_namespace s on s.oid = p.pronamespace
   where s.nspname = 'public' and p.proname = 'fn_crm_set_updated_at' and has_function_privilege('authenticated', p.oid, 'execute');
  r := r || 'fn_crm_set_updated_at ejecutable por authenticated: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;

  select count(*) into n from pg_class c join pg_namespace s on s.oid = c.relnamespace
   where s.nspname = 'public' and c.relname like 'crm\_%' and c.relkind = 'r' and not c.relrowsecurity;
  r := r || 'Tablas crm_* sin RLS: ' || n || ' (esperado 0)' || E'\n'; if n <> 0 then fallas := fallas + 1; end if;

  raise exception E'RESULTADO DE LA PRUEBA\n%FALLAS: %', r, fallas;
end $$;
