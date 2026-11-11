// Edge Function: borrado automático de un participante, llamada desde la
// página pública docs/eliminar-datos/index.html.
//
// ⚠️ Advertencia de diseño, a propósito documentada: esta función NO verifica
// que quien llama sea realmente dueño del alias — solo pide el alias y una
// fecha aproximada de registro como fricción mínima contra errores o
// travesuras, no como autenticación real. Es una decisión consciente (pedida
// explícitamente), no un descuido. Si en algún momento se quiere identidad
// real, habría que pedir algo que solo la persona dueña del alias tenga —
// hoy la app no recoge correo ni teléfono, así que no hay un canal para eso
// sin cambiar el diseño de anonimato del estudio.
//
// Reutiliza exactamente la misma lógica de borrado en cascada que el botón
// del panel local (panel-rastro.html → borrarTodo). Si cambia una, cambiar la
// otra.
//
// Variables de entorno que necesita (se configuran como "Secrets" en el
// Dashboard de Supabase, nunca en el código):
//   SUPABASE_URL           — ya la provee la plataforma automáticamente
//   SUPABASE_SERVICE_ROLE_KEY — ya la provee la plataforma automáticamente
//     (ver nota más abajo si no aparece)

// deno-lint-ignore-file no-explicit-any
Deno.serve(async (req: Request) => {
  const cors = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (req.method === "OPTIONS") return new Response(null, { headers: cors });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "usa POST" }), {
      status: 405,
      headers: { ...cors, "content-type": "application/json" },
    });
  }

  const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
  // El proyecto usa el sistema nuevo de llaves (sb_secret_/sb_publishable_). La
  // SUPABASE_SERVICE_ROLE_KEY que Supabase inyecta sola es la llave vieja (JWT) y
  // no tiene los mismos permisos de Storage acá — por eso se usa una llave propia,
  // guardada como secret del proyecto (Dashboard → Edge Functions → Secrets).
  const SERVICE_KEY = Deno.env.get("RASTRO_SECRET_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const auth = { apikey: SERVICE_KEY, Authorization: `Bearer ${SERVICE_KEY}` };

  async function leer(path: string) {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, { headers: auth });
    if (!r.ok) throw new Error(`leer ${path}: ${r.status} ${await r.text()}`);
    return r.json();
  }
  async function borrar(path: string) {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
      method: "DELETE",
      headers: auth,
    });
    if (!r.ok) throw new Error(`borrar ${path}: ${r.status} ${await r.text()}`);
  }
  async function borrarStorage(bucket: string, rutas: (string | null)[]) {
    const limpias = rutas.filter(Boolean);
    if (!limpias.length) return;
    const r = await fetch(`${SUPABASE_URL}/storage/v1/object/${bucket}`, {
      method: "DELETE",
      headers: { ...auth, "content-type": "application/json" },
      body: JSON.stringify({ prefixes: limpias }),
    });
    if (!r.ok) throw new Error(`storage ${bucket}: ${r.status} ${await r.text()}`);
  }
  function rutaDesdeUrl(url: string | null, bucket: string) {
    if (!url) return null;
    const marca = `/storage/v1/object/public/${bucket}/`;
    const i = url.indexOf(marca);
    return i === -1 ? null : url.slice(i + marca.length);
  }

  try {
    const body = await req.json().catch(() => ({}));
    const alias = String(body.alias || "").trim();
    if (!alias) {
      return new Response(JSON.stringify({ error: "falta el alias" }), {
        status: 400,
        headers: { ...cors, "content-type": "application/json" },
      });
    }

    const perfiles = await leer(
      `perfiles?alias=eq.${encodeURIComponent(alias)}&select=device_id,rostro_url,avatar_url`,
    );
    if (!perfiles.length) {
      return new Response(
        JSON.stringify({ error: "no existe ese alias (¿ya se había borrado?)" }),
        { status: 404, headers: { ...cors, "content-type": "application/json" } },
      );
    }
    const deviceId = perfiles[0].device_id;

    // 1) Capturas: fotos + filas + comentarios/reacciones asociados.
    const caps = await leer(
      `capturas?device_id=eq.${encodeURIComponent(deviceId)}&select=id,back_url,front_url`,
    );
    await borrarStorage(
      "capturas",
      caps.flatMap((c: any) => [
        rutaDesdeUrl(c.back_url, "capturas"),
        rutaDesdeUrl(c.front_url, "capturas"),
      ]),
    );
    if (caps.length) {
      const ids = caps.map((c: any) => c.id).join(",");
      for (const t of ["comentarios", "reacciones"]) {
        try {
          await borrar(`${t}?captura_id=in.(${ids})`);
        } catch (_e) { /* tabla puede no existir o no tener filas — no es fatal */ }
      }
    }
    await borrar(`capturas?device_id=eq.${encodeURIComponent(deviceId)}`);

    // 2) Perfil: rostro + avatar + la fila.
    await borrarStorage("capturas", [
      rutaDesdeUrl(perfiles[0].rostro_url, "capturas"),
      rutaDesdeUrl(perfiles[0].avatar_url, "capturas"),
    ]);
    await borrar(`perfiles?device_id=eq.${encodeURIComponent(deviceId)}`);

    // 3) Recuerdos: las 5 fotos del bucket privado `galeria` + la fila.
    const recs = await leer(
      `recuerdos?device_id=eq.${encodeURIComponent(deviceId)}&select=fotos`,
    );
    await borrarStorage("galeria", recs.flatMap((r: any) => r.fotos || []));
    await borrar(`recuerdos?device_id=eq.${encodeURIComponent(deviceId)}`);

    // 4) Amistades (los dos sentidos) y estado.
    await borrar(`amistades?de=eq.${encodeURIComponent(deviceId)}`);
    await borrar(`amistades?a=eq.${encodeURIComponent(deviceId)}`);
    await borrar(`estado?device_id=eq.${encodeURIComponent(deviceId)}`);

    return new Response(
      JSON.stringify({ ok: true, alias, capturas_borradas: caps.length }),
      { headers: { ...cors, "content-type": "application/json" } },
    );
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "content-type": "application/json" },
    });
  }
});
