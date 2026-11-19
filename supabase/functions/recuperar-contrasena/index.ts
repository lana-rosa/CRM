// Recuperar contraseña solo para colaboradores del CRM.
// Pública (sin sesión) a propósito: quien olvidó la contraseña no puede ingresar.
// La revisión y el límite de intentos viven en la base (crm_intentar_recuperacion); aquí solo se envía el correo.
// Respuestas NEUTRAS: { estado: 'enviado' | 'limite' | 'error' }.
// 'enviado' se responde igual para colaboradores y no colaboradores (así nadie descubre qué correos son de colaboradores);
// solo se envía el correo si es colaborador. 'limite' = demasiados intentos desde el mismo aparato.
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

const pausa = (ms: number) => new Promise((r) => setTimeout(r, ms));

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
  if (!email || email.length > 254 || !email.includes("@")) return responder("enviado");

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
  if (estado !== "ok") {
    // No es colaborador (o ya se enviaron 3 en la hora): no se envía nada y se responde igual que si se hubiera enviado.
    // La pausa imita lo que tarda el envío real, para que el tiempo de respuesta no delate nada.
    await pausa(700 + Math.random() * 600);
    return responder("enviado");
  }

  const publico = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error: errEnvio } = await publico.auth.resetPasswordForEmail(email, { redirectTo: REDIRECT });
  if (errEnvio) {
    if (errEnvio.status === 429) return responder("enviado"); // Supabase solo deja pedir 1 enlace por minuto: ya se envió uno
    return responder("error", 502);
  }
  return responder("enviado");
});
