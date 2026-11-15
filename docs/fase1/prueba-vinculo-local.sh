#!/usr/bin/env bash
# Prueba LOCAL de propuesta-vinculo-pedidos.sql (NO toca ninguna base real).
# Requiere un Postgres local con permiso para crear una base desechable.
#   cd docs/fase1 && PSQL="psql" ./prueba-vinculo-local.sh
# Recorre: prueba (deshace) -> aplicar -> no se aplica dos veces -> vuelta atrás -> casos de error.
set -u
PSQL=${PSQL:-psql}
DB=prueba_vinculo
FALLAS=0
ok()  { echo "  OK   $1"; }
mal() { echo "  FALLA $1"; FALLAS=$((FALLAS+1)); }
q()   { $PSQL -X -q -tA -d $DB -c "$1"; }
run() { $PSQL -X -q -d $DB -f "$1" 2>&1; }

$PSQL -X -q -d postgres -c "drop database if exists $DB" -c "create database $DB" 2>&1 | grep -v NOTICE
$PSQL -X -q -v ON_ERROR_STOP=1 -d $DB -f stub-erp-local.sql 2>&1 | grep ERROR
$PSQL -X -q -v ON_ERROR_STOP=1 -d $DB -f semilla-vinculo-local.sql 2>&1 | grep ERROR
ESTADO0=$(q "select count(*) filter (where tercero_id is null)||'/'||count(*) from pedidos_canal_venta")
echo "Estado inicial (sin cliente/total): $ESTADO0  (esperado 18/28)"
[ "$ESTADO0" = "18/28" ] && ok "semilla" || mal "semilla"

echo "1) Modo PRUEBA (v_aplicar=false): debe mostrar los conteos y deshacerlo todo"
OUT=$(run propuesta-vinculo-pedidos.sql)
echo "$OUT" | grep -q "FALLAS: 0" && ok "la prueba termina con FALLAS: 0" || mal "la prueba no dio FALLAS: 0"
echo "$OUT" | grep -q "antes 10  →  después 26" && ok "conteo con cliente 10 → 26" || mal "conteo con cliente"
echo "$OUT" | grep -q "antes 18  →  después 2" && ok "conteo sin cliente 18 → 2" || mal "conteo sin cliente"
echo "$OUT" | grep -q "igual antes y después: true" && ok "huella de la tabla igual" || mal "huella"
[ "$(q "select count(*) filter (where tercero_id is null)||'/'||count(*) from pedidos_canal_venta")" = "$ESTADO0" ] && ok "la prueba NO dejó cambios" || mal "la prueba dejó cambios"

echo "2) APLICAR (v_aplicar=true)"
sed 's/v_aplicar constant boolean := false/v_aplicar constant boolean := true/' propuesta-vinculo-pedidos.sql > /tmp/_aplicar.sql
OUT=$(run /tmp/_aplicar.sql)
echo "$OUT" | grep -q "APLICADO" && ok "aplicó" || mal "no aplicó: $OUT"
[ "$(q "select count(*) filter (where tercero_id is null)||'/'||count(*) from pedidos_canal_venta")" = "2/28" ] && ok "quedan 2 sin cliente de 28 (los 2 sin vínculo CRM)" || mal "conteo tras aplicar"
[ "$(q "select count(*) from _disparos")" = "0" ] && ok "ningún disparador de estado se activó" || mal "se activó un disparador"
[ "$(q "select count(*) from pedidos_canal_venta where tercero_id is null and referencia_crm_id is not null")" = "0" ] && ok "todos los pedidos con vínculo CRM ya tienen cliente" || mal "quedan pedidos con vínculo CRM sin cliente"
[ "$(q "select string_agg(consecutivo, ',' order by consecutivo) from pedidos_canal_venta where tercero_id is null")" = "PED-2026-00553,PED-2026-00562" ] && ok "los 2 sin cliente son PED-2026-00553 y PED-2026-00562" || mal "los 2 sin cliente no son los esperados"

echo "3) Aplicar por segunda vez: la guarda debe frenarlo sin cambiar nada"
OUT=$(run /tmp/_aplicar.sql)
echo "$OUT" | grep -q "No se cambió nada" && ok "la guarda frena la segunda aplicación" || mal "la segunda aplicación no fue frenada"

echo "4) VUELTA ATRÁS (bloque comentado del archivo)"
awk '/^-- do \$vuelta\$/{f=1} f{sub(/^-- ?/,"")} {print}' propuesta-vinculo-pedidos.sql | awk '/^do \$vuelta\$/{f=1} f{print} /^\$vuelta\$;/{f=0}' > /tmp/_vuelta.sql
OUT=$(run /tmp/_vuelta.sql)
echo "$OUT" | grep -q "devueltos a \"sin cliente\": 16" && ok "la vuelta atrás devolvió 16 pedidos" || mal "vuelta atrás: $OUT"
[ "$(q "select count(*) filter (where tercero_id is null)||'/'||count(*) from pedidos_canal_venta")" = "$ESTADO0" ] && ok "queda EXACTAMENTE como al inicio (18/28)" || mal "la vuelta atrás no restauró"
[ "$(q "select count(*) from pedidos_canal_venta where tercero_id is not null")" = "10" ] && ok "los 10 pedidos que ya tenían cliente no se tocaron" || mal "se tocaron los que ya tenían cliente"

echo "5) Casos de error: no debe cambiar nada"
q "update terceros set crm_cliente_id = gen_random_uuid() where id = 'b90646ef-8c1e-41d1-9a05-69ec97228091'" >/dev/null
OUT=$(run propuesta-vinculo-pedidos.sql); echo "$OUT" | grep -q "Guarda: solo" && ok "tercero con otro crm_cliente_id: la guarda frena" || mal "mismatch de tercero no frenado"
q "update terceros set crm_cliente_id='6cf316e6-fe95-4c31-802f-f4b32e2e9aff', acepta_tratamiento_datos=false where id = 'b90646ef-8c1e-41d1-9a05-69ec97228091'" >/dev/null
OUT=$(run propuesta-vinculo-pedidos.sql); echo "$OUT" | grep -q "Guarda: solo" && ok "tercero sin autorización de datos: la guarda frena" || mal "tercero sin autorización no frenado"
q "update terceros set acepta_tratamiento_datos=true where id = 'b90646ef-8c1e-41d1-9a05-69ec97228091'" >/dev/null
q "update pedidos_canal_venta set tercero_id='8c7984b1-01f1-404f-ab49-7c313642b831' where consecutivo='PED-2026-00469'" >/dev/null
OUT=$(run /tmp/_aplicar.sql); echo "$OUT" | grep -q "Guarda: solo" && ok "un pedido que ya tiene cliente: la guarda frena y NO lo pisa" || mal "se pisó un cliente ya asignado"
[ "$(q "select tercero_id from pedidos_canal_venta where consecutivo='PED-2026-00469'")" = "8c7984b1-01f1-404f-ab49-7c313642b831" ] && ok "el cliente ya asignado sigue igual" || mal "cambió el cliente ya asignado"
[ "$(q "select count(*) from pedidos_canal_venta where tercero_id is not null")" = "11" ] && ok "ningún otro pedido cambió (10 + el asignado a mano)" || mal "cambió otro pedido"

if [ $FALLAS -eq 0 ]; then echo "TODO BIEN: prueba, aplicación, segunda aplicación frenada, vuelta atrás y casos de error"; else echo "$FALLAS FALLAS"; exit 1; fi
