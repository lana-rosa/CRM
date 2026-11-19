-- Recuperación de contraseña: respuestas neutras (19-nov-2026).
-- Cambio: el tope de 3 envíos por hora POR CORREO ya no devuelve 'limite' (eso delataba que el correo es de un colaborador);
-- ahora no se envía más y se responde igual que a un correo no registrado ('no_existe').
-- El tope por aparato (3 intentos por hora) sigue devolviendo 'limite': cuenta todos los intentos, existan o no los correos.
create or replace function public.crm_intentar_recuperacion(p_email text, p_ip text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_sal    constant text := 'e5def33bdd2fae34fa182fab2f53c779';
  c_max    constant int  := 3;
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

  select count(*) into v_n_ip from public.crm_recuperacion_intentos
   where ip_hash = v_ih and creado > now() - interval '1 hour';
  select count(*) into v_n_mail from public.crm_recuperacion_intentos
   where email_hash = v_eh and resultado = 'ok' and creado > now() - interval '1 hour';

  if v_n_ip >= c_max then
    return 'limite';
  end if;
  if v_n_mail >= c_max then
    return 'no_existe';   -- ya se enviaron 3 en la última hora: no se envía otro y no se delata nada
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

revoke all on function public.crm_intentar_recuperacion(text, text) from public, anon, authenticated;
grant execute on function public.crm_intentar_recuperacion(text, text) to service_role;
