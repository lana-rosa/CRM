// Recuperar contraseña solo para colaboradores del CRM.
// Pública (sin sesión) a propósito: quien olvidó la contraseña no puede ingresar.
// La revisión y el límite de intentos viven en la base (crm_intentar_recuperacion); aquí solo se envía el correo.
// Respuestas: { estado: 'enviado' | 'no_existe' | 'limite' | 'espera' | 'error' }
import { createClient } from "npm:@supabase/supabase-js@2.118.0";

const ORIGEN = "https://lana-rosa.github.io";
const REDIRECT = "https://lana-rosa.github.io/CRM/";

const cors = {
  "Access-Control-Allow-Origin": ORIGEN,
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Vary": "Origin",
};

function responder(estado: string, status = 200) {
  return new Response(JSON.stringify({ estado }), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function direccionDelAparato(req: Request): string {
  const cf = req.headers.get("cf-connecting-ip");
  if (cf) return cf.trim();
  const xff = req.headers.get("x-forwarded-for");
  if (xff) return xff.split(",").pop()!.trim(); // el último lo agrega la infraestructura, el primero lo puede escribir cualquiera
  return "sin-ip";
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return responder("error", 405);

  let email = "";
  try {
    const body = await req.json();
    email = typeof body?.email === "string" ? body.email.trim().toLowerCase() : "";
  } catch (_) {
    return responder("error", 400);
  }
  if (!email || email.length > 254 || !email.includes("@")) return responder("no_existe");

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: estado, error } = await admin.rpc("crm_intentar_recuperacion", {
    p_email: email,
    p_ip: direccionDelAparato(req),
  });
  if (error) return responder("error", 500);
  if (estado === "limite") return responder("limite", 429);
  if (estado !== "ok") return responder("no_existe"); // no es colaborador: no se envía nada

  const publico = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: errEnvio } = await publico.auth.resetPasswordForEmail(email, { redirectTo: REDIRECT });
  if (errEnvio) {
    if (errEnvio.status === 429) return responder("espera", 429);
    return responder("error", 502);
  }
  return responder("enviado");
});
