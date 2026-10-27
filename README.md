# rastro

App del proyecto de tesis **rastro** (diseño, UDP): una app social tipo *BeReal* que,
detrás de una fachada de archivo de redes sociales, captura la **ubicación en el origen**
de cada foto y construye un **expediente** del recorrido de cada persona. El dato existe
desde el primer momento, pero la app nunca se lo muestra al usuario: se revela después,
en una entrevista, impreso en papel térmico. Es un ejercicio de diseño crítico sobre la
**resignación informada** frente a la vigilancia algorítmica.

> Antes este repo era un lector de EXIF. Eso quedó obsoleto: ahora el GPS se captura **en
> el momento de la foto** (no del EXIF), que es justo lo que en los 2010 se perdía.

## El sistema (tres piezas)

1. **App Flutter (este repo)** — lo que usa el participante. Captura, perfil, feed social,
   notificaciones. Sube todo a Supabase.
2. **Backend Supabase** — base de datos + almacenamiento de fotos. Llaves públicas
   (publishable key) embebidas en la app por diseño; RLS permisivo para un test cerrado
   con consentimiento.
3. **Herramientas de investigador** (viven en `rastro 2/`, fuera de este repo):
   - `panel-rastro.html` — panel web que lee Supabase: mapa, patrones por comuna,
     malla biométrica facial, escáner teatral de identificación, seguimiento
     post-revelación.
   - `imprimir_expediente.py` — imprime el expediente de cada participante en una
     impresora térmica **Sewoo SLK-TS400** (ESC/POS por USB).

## Qué hace la app

- **Onboarding**: inicio minimal → términos y condiciones → **verificación biométrica**
  (enrolamiento facial por pasos, estilo Face ID, con Vision) → **crear perfil** (foto
  elegida + nombre). El rostro biométrico es la llave de identificación de la
  investigadora; es distinto de la foto de perfil pública.
- **Captura dual**: una foto trasera + una frontal **al mismo tiempo**
  (`AVCaptureMultiCamSession`, nativo en Swift), con el **GPS capturado en el momento**.
- **Feed social**: amigos reales (se agregan entre participantes), detalle de post con
  reacciones y comentarios, perfiles tocables. Mecánica BeReal: publica para ver a los
  demás.
- **Notificaciones**: una al día a hora definida en la **agenda** de Supabase (misma hora
  para todos) con jitter, programadas localmente (sin servidor de push).
- **Latido**: registra último acceso + estado de permisos + nº de capturas, para medir el
  comportamiento **después de la revelación**.
- **Modo desarrollador** (oculto: mantener presionado el wordmark): trastienda con el GPS
  extraído de cada captura, programar notificaciones, exportar JSON.

## Estructura (`lib/`)

| Archivo | Rol |
|---|---|
| `main.dart` | Shell con barra inferior (Feed · Amigos · Perfil), feed, onboarding |
| `terminos_screen.dart` | Términos y condiciones (consentimiento) |
| `biometria_screen.dart` | Enrolamiento facial por pasos |
| `perfil_editor.dart` | Crear/editar perfil (foto elegida + nombre) |
| `perfil_screen.dart` / `otro_perfil_screen.dart` | Tu perfil / el de otro participante |
| `amigos_screen.dart` | Lista de participantes, buscar y agregar |
| `remote_post_detalle.dart` | Detalle de post (reacciones, comentarios) |
| `capture_flow.dart` | Flujo de captura (cámara dual + GPS); puente al nativo |
| `captures.dart` | Modelo `Capture` + almacenamiento local |
| `notifications.dart` | Notificaciones locales + lectura de la agenda |
| `backend.dart` | Supabase: perfiles, capturas, amistades, estado, agenda, avatar |
| `ajustes_screen.dart` | Cómo funciona · estado de notis · salir del estudio |
| `dev_screen.dart` | Trastienda (modo desarrollador) |
| `photo.dart` / `theme.dart` | Widgets de foto (dual, grano) / identidad gráfica rastro |

El código nativo de cámara dual y escáner facial está en
`ios/Runner/AppDelegate.swift` (platform channel `rastro/multicam`).

## Backend (Supabase)

Tablas: `perfiles` (alias, device_id, rostro_url, avatar_url), `capturas` (2 fotos + GPS +
hora + alias), `amistades`, `estado` (latido), `agenda` (horarios de notificación).
Bucket público `capturas` para las fotos. El esquema está en `supabase_schema.sql`. La
configuración (URL + publishable key) está en `lib/backend.dart`.

## Correr en iOS

Desarrollo principalmente **iPhone** (la cámara dual y el GPS no se prueban en simulador).

```sh
flutter pub get
cd ios && pod install && cd ..
# Build + instalar en un iPhone conectado (requiere Modo Desarrollador activo):
```

Por el roce entre Flutter y Xcode 26, el pipeline se hace con `xcodebuild` + `devicectl`
en vez de `flutter run`:

```sh
cd ios
xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> \
  build/Build/Products/Release-iphoneos/Runner.app
```

## Límites y notas

- **Firma gratis (Personal Team)**: la app caduca a los 7 días y cada dispositivo debe
  registrarse. Para repartir a voluntarios se necesita **TestFlight** (cuenta Apple de
  pago).
- Las notificaciones son **locales** (no push): no necesitan servidor, pero la hora debe
  estar definida con antelación en la agenda.
- La identificación en la entrevista es **manual con confirmación visual** (la
  investigadora sostiene la llave rostro ↔ alias), no reconocimiento automático.

## Bibliotecas

`image_picker`, `geolocator`, `flutter_local_notifications`, `timezone`, `path_provider`,
`shared_preferences`, `google_fonts`, `supabase_flutter`.
