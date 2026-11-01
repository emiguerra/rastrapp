-- rastro · Endurecimiento de seguridad (Opción 1, piloto cerrado)
-- Córrelo en: Supabase → SQL Editor → New query → Run.
--
-- Qué hace: convierte `capturas` en APPEND-ONLY. Se puede insertar y leer, pero
-- NADIE puede borrar ni modificar una captura desde el cliente (la evidencia —
-- fotos + GPS — queda a prueba de manipulación y borrado).
--
-- Qué NO hace (límite honesto): con la llave pública y sin login, el SELECT sigue
-- abierto; alguien con la llave aún podría LEER datos. Cerrar la lectura requiere
-- autenticación (Opción 2). Para limpiar datos de prueba, usa el Table Editor del
-- dashboard (no la app).

-- ── capturas: append-only (insertar + leer; sin update ni delete) ──
drop policy if exists "capturas todo"     on public.capturas;
drop policy if exists "capturas insertar" on public.capturas;
drop policy if exists "capturas leer"     on public.capturas;

create policy "capturas insertar" on public.capturas
  for insert with check (true);
create policy "capturas leer" on public.capturas
  for select using (true);
-- (a propósito: no se crean políticas de UPDATE ni DELETE)

-- Las demás tablas (perfiles, estado, amistades) conservan sus políticas porque
-- la app necesita actualizar el perfil, el latido y agregar/quitar amigos. Su
-- manipulación no es catastrófica y queda como riesgo residual documentado.
