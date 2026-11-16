#!/usr/bin/env bash
# Prueba LOCAL de posventa.sql (NO toca ninguna base real). Requiere Postgres local.
#   cd docs/fidelizacion && PSQL="psql" ./prueba-posventa-local.sh
set -u
PSQL=${PSQL:-psql}; DB=prueba_posventa; FALLAS=0
ok(){ echo "  OK   $1"; }; mal(){ echo "  FALLA $1"; FALLAS=$((FALLAS+1)); }
q(){ $PSQL -X -q -tA -d $DB -c "$1" 2>&1; }
eq(){ [ "$(q "$1")" = "$2" ] && ok "$3" || mal "$3 (obtuvo: $(q "$1"))"; }
$PSQL -X -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>&1 | grep -v NOTICE
$PSQL -X -q -v ON_ERROR_STOP=1 -d $DB -f ../fase1/stub-erp-local.sql 2>&1 | grep ERROR
$PSQL -X -q -v ON_ERROR_STOP=1 -d $DB -f stub-posventa-local.sql 2>&1 | grep ERROR
$PSQL -X -q -v ON_ERROR_STOP=1 -1 -d $DB -f posventa.sql 2>&1 | grep -E "ERROR" && mal "posventa.sql no aplica" || ok "posventa.sql aplica sin errores"

# Semilla: A (cuenta+novedades, entregado hace 6 d), B (sin novedades, hace 6 d), C (novedades, hace 2 d),
# D (novedades, hace 6 d, SIN correo ni teléfono), E (novedades, hace 6 d, dos pedidos), F (novedades, entregado hace 90 d), G (novedades, entregado hace 6 d, antes del corte)
$PSQL -X -q -v ON_ERROR_STOP=1 -d $DB <<'SQL'
insert into centros_costo(codigo,nombre) values ('99','x') on conflict do nothing;
create temp table cc as select id from centros_costo limit 1;
do $$ declare cc uuid; begin select id into cc from centros_costo limit 1;
 insert into terceros(id,numero_documento,nombre_completo,email,telefono,primer_nombre) values
  ('00000000-0000-0000-0000-00000000000a','1','Ana Pérez','ana@x.co','3001',null),
  ('00000000-0000-0000-0000-00000000000b','2','Beto Ruiz','beto@x.co','3002','Beto'),
  ('00000000-0000-0000-0000-00000000000c','3','Cami Gil','cami@x.co','3003',null),
  ('00000000-0000-0000-0000-00000000000d','4','Dani Sol',null,null,null),
  ('00000000-0000-0000-0000-00000000000e','5','Eli <b>Mora','eli@x.co',null,null),
  ('00000000-0000-0000-0000-00000000000f','6','Fer Luz','fer@x.co','3006',null);
 insert into pedidos_canal_venta(id,consecutivo,canal,centro_costo_id,tercero_id,descripcion_producto,total_pedido,estado) values
  ('10000000-0000-0000-0000-00000000000a','PED-A','whatsapp',cc,'00000000-0000-0000-0000-00000000000a','Oso',1,'entregado'),
  ('10000000-0000-0000-0000-00000000000b','PED-B','whatsapp',cc,'00000000-0000-0000-0000-00000000000b','Gato',1,'entregado'),
  ('10000000-0000-0000-0000-00000000000c','PED-C','whatsapp',cc,'00000000-0000-0000-0000-00000000000c','Perro',1,'entregado'),
  ('10000000-0000-0000-0000-00000000000d','PED-D','whatsapp',cc,'00000000-0000-0000-0000-00000000000d','Rana',1,'entregado'),
  ('10000000-0000-0000-0000-0000000000e1','PED-E1','whatsapp',cc,'00000000-0000-0000-0000-00000000000e','Pez',1,'entregado'),
  ('10000000-0000-0000-0000-0000000000e2','PED-E2','whatsapp',cc,'00000000-0000-0000-0000-00000000000e','Pato',1,'entregado'),
  ('10000000-0000-0000-0000-00000000000f','PED-F','whatsapp',cc,'00000000-0000-0000-0000-00000000000f','Vaca',1,'entregado'),
  ('10000000-0000-0000-0000-000000000099','PED-G','whatsapp',cc,'00000000-0000-0000-0000-00000000000a','Ave',1,'en_preparacion');
 insert into pedidos_canal_historial(pedido_id,estado,created_at) values
  ('10000000-0000-0000-0000-00000000000a','entregado',now()-interval '6 days'),
  ('10000000-0000-0000-0000-00000000000b','entregado',now()-interval '6 days'),
  ('10000000-0000-0000-0000-00000000000c','entregado',now()-interval '2 days'),
  ('10000000-0000-0000-0000-00000000000d','entregado',now()-interval '6 days'),
  ('10000000-0000-0000-0000-0000000000e1','entregado',now()-interval '7 days'),
  ('10000000-0000-0000-0000-0000000000e2','entregado',now()-interval '6 days'),
  ('10000000-0000-0000-0000-00000000000f','entregado',now()-interval '90 days');
 insert into cuentas_clientes_web(user_id,tercero_id) select gen_random_uuid(), id from terceros where id::text not like '%00b';
 insert into cuentas_novedades(user_id,acepta) select user_id, true from cuentas_clientes_web;
end $$;
SQL

echo "1) Apagada: no hace nada"
eq "select fn_crm_posventa_programar(false)" "0" "apagada: programa 0"
eq "select fn_crm_posventa_enviar_correos()" "0" "apagada: envía 0"
eq "select count(*) from net._llamadas" "0" "apagada: ningún correo"
echo "2) No se puede encender sin desde_entregados"
q "update crm_posventa_config set activo = true" | grep -q "violates check" && ok "exige desde_entregados" || mal "dejó encender sin corte"
echo "3) Encendida con corte de hace 30 días (F, de hace 90, queda fuera)"
q "update crm_posventa_config set activo = true, desde_entregados = current_date - 30" >/dev/null
eq "select fn_crm_posventa_programar(true)" "2" "simulación: solo A y E (B sin novedades, C muy reciente, D sin contacto, F muy viejo)"

echo "4) Programar de verdad"
eq "select fn_crm_posventa_programar(false)" "2" "crea 2 registros"
eq "select fn_crm_posventa_programar(false)" "0" "segunda vez no duplica"
eq "select string_agg(p.consecutivo, ',' order by p.consecutivo) from crm_posventa s join pedidos_canal_venta p on p.id=s.pedido_id" "PED-A,PED-E1" "E: se pregunta por el primer pedido, no por los dos"
eq "select whatsapp_estado from crm_posventa s join pedidos_canal_venta p on p.id=s.pedido_id where consecutivo='PED-E1'" "omitido" "sin teléfono: WhatsApp omitido"
echo "5) Correos"
eq "select fn_crm_posventa_enviar_correos()" "2" "envía 2"
eq "select fn_crm_posventa_enviar_correos()" "0" "no reenvía"
eq "select count(*) from net._llamadas where headers->>'Idempotency-Key' like 'posventa-%' and body->'headers'->>'List-Unsubscribe' like '<https://lanarosacrochet.com/baja.html?t=%'" "2" "Idempotency-Key y enlace de baja en cada correo"
eq "select count(*) from net._llamadas where body->>'html' like '%share.google%' and body->>'html' like '%cuenta.html%' and body->>'html' like '%encuesta.html?t=%'" "2" "cada correo trae encuesta + web + Google"
eq "select count(*) from net._llamadas where body->>'html' ~* 'navidad|halloween|santo'" "0" "sin Navidad/santos/Halloween"
echo "6) Seguridad: anon"
T=$(q "select token from crm_posventa s join pedidos_canal_venta p on p.id=s.pedido_id where consecutivo='PED-A'")
[ ${#T} -eq 64 ] && ok "token de 64 caracteres" || mal "token de largo ${#T}"
q "set role anon; select count(*) from crm_posventa" | grep -q "permission denied" && ok "anon no lee crm_posventa" || mal "anon lee crm_posventa"
q "set role anon; select count(*) from crm_posventa_respuestas" | grep -q "permission denied" && ok "anon no lee respuestas" || mal "anon lee respuestas"
q "set role anon; select count(*) from v_crm_posventa_candidatas" | grep -q "permission denied" && ok "anon no lee candidatas" || mal "anon lee candidatas"
q "set role anon; select fn_crm_posventa_programar(true)" | grep -q "permission denied" && ok "anon no ejecuta programar" || mal "anon ejecuta programar"
q "set role anon; select fn_crm_posventa_pendientes()" | grep -q "permission denied" && ok "anon no ejecuta pendientes" || mal "anon ejecuta pendientes"
q "set role anon; select encuesta_posventa_responder('$T',5,5,'si','x')" >/dev/null
q "update crm_posventa set respondida_at=null where false" >/dev/null
echo "7) Encuesta con token"
eq "set role anon; select encuesta_posventa_ver('no-existe')::jsonb->>'estado'" "invalida" "token falso: inválida"
eq "select (select count(*) from crm_posventa_respuestas)" "1" "la respuesta de arriba quedó guardada (anon pudo por la función)"
eq "set role anon; select encuesta_posventa_ver('$T')::jsonb->>'estado'" "respondida" "ya respondida"
eq "set role anon; select encuesta_posventa_responder('$T',1,1,'no','otra vez')::jsonb->>'estado'" "respondida" "no se responde dos veces"
eq "select count(*) from crm_tareas" "0" "nota alta: no crea tarea"
T2=$(q "select token from crm_posventa s join pedidos_canal_venta p on p.id=s.pedido_id where consecutivo='PED-E1'")
eq "set role anon; select encuesta_posventa_responder('$T2',9,5,'si',null)::jsonb->>'estado'" "datos_invalidos" "estrellas fuera de 1-5: rechazada"
R=$(q "set role anon; select encuesta_posventa_responder('$T2',2,5,'no','llegó tarde')" | tail -1)
echo "$R" | grep -q '"ok": true' && ok "respuesta con notas bajas se acepta" || mal "notas bajas: $R"
echo "$R" | grep -q 'share.google' && echo "$R" | grep -q 'cuenta.html' && ok "con notas bajas igual recibe la invitación a Google y a la web" || mal "con notas bajas NO recibió la invitación"
eq "select count(*) from crm_tareas where titulo like 'Posventa%'" "1" "nota baja: crea tarea interna"
echo "8) Vencida"
q "insert into pedidos_canal_venta(id,consecutivo,canal,centro_costo_id,tercero_id,descripcion_producto,total_pedido,estado) select '10000000-0000-0000-0000-0000000000aa','PED-V','whatsapp',centro_costo_id,tercero_id,'Oso',1,'entregado' from pedidos_canal_venta where consecutivo='PED-A'" >/dev/null
q "insert into crm_posventa(pedido_id,tercero_id,entregado_at,vence_at,correo_estado,whatsapp_estado,token) select '10000000-0000-0000-0000-0000000000aa',tercero_id,now()-interval '40 days',now()-interval '1 day','omitido','pendiente','venc' from crm_posventa limit 1" >/dev/null
eq "set role anon; select encuesta_posventa_ver('venc')::jsonb->>'estado'" "vencida" "vencida"
eq "set role anon; select encuesta_posventa_responder('venc',5,5,'si',null)::jsonb->>'estado'" "vencida" "vencida no acepta respuesta"
echo "9) Funciones de la administradora"
q "insert into usuarios_roles values ('aaaaaaaa-0000-0000-0000-000000000001','administrador',true),('aaaaaaaa-0000-0000-0000-000000000002','cajero',true)" >/dev/null
adm(){ q "set role authenticated; select set_config('request.jwt.claims','{\"sub\":\"aaaaaaaa-0000-0000-0000-00000000000$1\"}',true); $2" | grep -v '^{' | tail -${3:-1}; }
q "insert into pedidos_canal_venta(id,consecutivo,canal,centro_costo_id,tercero_id,descripcion_producto,total_pedido,estado) select '10000000-0000-0000-0000-0000000000bb','PED-W','whatsapp',centro_costo_id,'00000000-0000-0000-0000-00000000000c','Conejo',1,'entregado' from pedidos_canal_venta limit 1" >/dev/null
q "insert into crm_posventa(pedido_id,tercero_id,entregado_at,vence_at,correo_estado,whatsapp_estado) values ('10000000-0000-0000-0000-0000000000bb','00000000-0000-0000-0000-00000000000c',now()-interval '6 days',now()+interval '20 days','enviado','pendiente')" >/dev/null
[ "$(adm 1 "select count(*) from fn_crm_posventa_pendientes()")" = "1" ] && ok "administradora ve 1 pendiente de WhatsApp (la de Cami)" || mal "pendientes: $(adm 1 "select count(*) from fn_crm_posventa_pendientes()")"
adm 1 "select enlace from fn_crm_posventa_pendientes()" | grep -q "encuesta.html?t=" && ok "el enlace de la encuesta viene armado" || mal "enlace mal armado"
adm 2 "select count(*) from fn_crm_posventa_pendientes()" 5 | grep -q "sin permiso" && ok "cajero no puede" || mal "cajero pudo ver pendientes: $(adm 2 "select count(*) from fn_crm_posventa_pendientes()")"
adm 1 "select fn_crm_posventa_marcar_whatsapp(id) from crm_posventa where whatsapp_estado='pendiente' and respondida_at is null and vence_at>now()" >/dev/null
[ "$(adm 1 "select count(*) from fn_crm_posventa_pendientes()")" = "0" ] && ok "marcar como enviado la saca de la lista" || mal "marcar no funcionó"
[ "$(adm 1 "select count(*) from fn_crm_posventa_resultados()")" = "2" ] && ok "resultados: 2 respuestas" || mal "resultados: $(adm 1 "select count(*) from fn_crm_posventa_resultados()")"

echo; [ $FALLAS -eq 0 ] && echo "TODO OK" || echo "FALLAS: $FALLAS"
