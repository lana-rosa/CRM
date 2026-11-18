-- Recuperación de contraseña solo para colaboradores (CRM, 18-nov-2026).
-- Tabla de intentos + función cerrada (solo la llama la función de borde `recuperar-contrasena` con la llave de servicio).
-- Los correos y las direcciones de red se guardan cifrados (sha256 con sal), nunca en claro.

create table if not exists public.crm_recuperacion_intentos (
  id          bigint generated always as identity primary key,
  creado      timestamptz not null default now(),
  ip_hash     text not null,
  email_hash  text not null,
  resultado   text not null check (resultado in ('ok','no_existe'))
);
create index if not exists crm_recuperacion_intentos_ip_idx    on public.crm_recuperacion_intentos (ip_hash, creado);
create index if not exists crm_recuperacion_intentos_email_idx on public.crm_recuperacion_intentos (email_hash, creado);

alter table public.crm_recuperacion_intentos enable row level security;   -- sin políticas: nadie la lee ni escribe por la API
revoke all on public.crm_recuperacion_intentos from public, anon, authenticated;

comment on table public.crm_recuperacion_intentos is
  'Intentos de «¿Olvidaste tu contraseña?» (límite: 3 por hora por aparato y 3 envíos por hora por correo). Solo la usa crm_intentar_recuperacion.';

-- Devuelve: 'ok' (es colaborador: se puede enviar el enlace), 'no_existe' (no es colaborador: no se envía nada) o 'limite' (demasiados intentos).
create or replace function public.crm_intentar_recuperacion(p_email text, p_ip text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_sal    constant text := 'e5def33bdd2fae34fa182fab2f53c779';
  c_max    constant int  := 3;                      -- máximo de intentos por hora
  v_email  text := lower(btrim(coalesce(p_email, '')));
  v_eh     text;
  v_ih     text;
  v_n_ip   int;
  v_n_mail int;
  v_ok     boolean;
begin
  if v_email = '' or length(v_email) > 254 or position('@' in v_email) < 2 then
    return 'no_existe';
  end if;

  v_eh := encode(sha256(convert_to(c_sal || ':e:' || v_email, 'UTF8')), 'hex');
  v_ih := encode(sha256(convert_to(c_sal || ':i:' || coalesce(nullif(btrim(p_ip), ''), 'sin-ip'), 'UTF8')), 'hex');

  delete from public.crm_recuperacion_intentos where creado < now() - interval '1 day';

  -- límite por aparato: cuenta todos los intentos (existan o no los correos)
  select count(*) into v_n_ip from public.crm_recuperacion_intentos
   where ip_hash = v_ih and creado > now() - interval '1 hour';
  -- límite por correo: cuenta solo los envíos reales (así nadie gasta los intentos de otra persona escribiendo su correo)
  select count(*) into v_n_mail from public.crm_recuperacion_intentos
   where email_hash = v_eh and resultado = 'ok' and creado > now() - interval '1 hour';

  if v_n_ip >= c_max or v_n_mail >= c_max then
    return 'limite';
  end if;

  select exists (
    select 1 from public.profiles p
     where lower(p.email) = v_email and p.role in ('admin', 'tejedora')
  ) into v_ok;

  insert into public.crm_recuperacion_intentos (ip_hash, email_hash, resultado)
  values (v_ih, v_eh, case when v_ok then 'ok' else 'no_existe' end);

  return case when v_ok then 'ok' else 'no_existe' end;
end;
$$;

-- Nace cerrada: solo la llave de servicio (la función de borde) puede llamarla.
revoke all on function public.crm_intentar_recuperacion(text, text) from public, anon, authenticated;
grant execute on function public.crm_intentar_recuperacion(text, text) to service_role;
