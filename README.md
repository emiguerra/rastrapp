# rastro

App del proyecto de tesis **rastro** (diseño, UDP). Por fuera es una red social de fotos
tipo *BeReal*: una foto al día, a una hora sorpresa. Por detrás captura la **ubicación en
el origen** de cada foto y construye un **expediente** del recorrido de cada persona. La app
nunca le muestra ese dato al usuario: se revela después, en una entrevista, impreso en papel
térmico. Es un ejercicio de diseño crítico sobre la **resignación informada** frente a la
vigilancia algorítmica.

## Decisión de diseño: la app es camuflaje

La app que usa el participante debe ser **indistinguible de una red social normal**: negro,
blanco, grises neutros, tipografía sans, sin marca llamativa. La identidad gráfica de rastro
(verde ácido, pixel, grano) **no vive aquí**: se reserva para la revelación (el panel de la
investigadora, el expediente impreso, la instalación).

No es una decisión estética. El estudio depende de que el participante crea que usa una red
social común; una marca vistosa avisaría que pasa algo raro y contaminaría lo que se mide.

## El sistema (tres piezas)

1. **App Flutter (este repo)**: lo que usa el participante. iOS y Android.
2. **Backend Supabase**: base de datos y almacenamiento de fotos.
3. **Herramientas de la investigadora** (viven fuera de este repo, son privadas porque leen
   rostros y ubicaciones): un panel web (mapa, comunas exactas, patrones, malla biométrica,
   identificación en la entrevista, seguimiento post-revelación) y un script que imprime el
   expediente en una impresora térmica **Sewoo SLK-TS400** (ESC/POS por USB).

## Qué hace la app

- **Onboarding**: inicio minimal → términos y condiciones → **registro facial** → **crear
  perfil** (foto elegida + nombre). El rostro del registro es la llave con la que la
  investigadora reconoce a la persona en la entrevista; es distinto de la foto de perfil.
- **Registro facial circular**: el usuario mueve la cabeza en círculo y los segmentos de un
  anillo se van llenando (detección con Vision). La vista previa va en espejo para que el
  movimiento se sienta natural; la foto que se guarda va **sin espejo**.
- **Captura dual** (iOS): foto trasera y frontal **al mismo tiempo**, con el **GPS tomado en
  ese instante**. Después de capturar hay una vista previa con **Publicar / Repetir /
  Cancelar**; nada se guarda hasta publicar.
- **Foto doble estilo BeReal**: tocar el recuadro chico intercambia frontal y trasera.
- **Feed social**: amigos reales entre participantes, detalle de post con reacciones y
  comentarios, perfiles tocables. Mecánica BeReal: publica para ver a los demás.
- **Memorias**: tu semana día a día (Perfil → ícono de calendario). La **racha** cuenta días
  consecutivos de verdad y se corta si se salta un día.
- **Notificaciones**: una al día a la hora definida en la **agenda** de Supabase (igual para
  todos, con un pequeño jitter). Son locales: no hay servidor de push.
- **Latido**: registra último acceso, estado de permisos y cantidad de capturas, para medir la
  conducta después de la revelación.
- **Ajustes**: cómo funciona, estado de las notificaciones, salir del estudio.
- **Modo desarrollador** (oculto: mantener presionado el nombre en el feed): trastienda con el
  GPS de cada captura, programar notificaciones, exportar JSON.

### iOS y Android

El código es el mismo; lo nativo de iOS tiene respaldo en Android.

| | iOS | Android |
|---|---|---|
| Cámara | dual simultánea (2 fotos) | una foto (cámara del sistema) |
| Registro facial | escáner circular nativo | selfie simple |
| GPS, comunas, expediente | igual | igual |
| Distribución | TestFlight | APK por enlace |

## Estructura (`lib/`)

| Archivo | Rol |
|---|---|
| `main.dart` | Shell con barra inferior (Feed · Amigos · Perfil), feed y onboarding |
| `terminos_screen.dart` | Términos y condiciones (consentimiento) |
| `biometria_screen.dart` | Registro facial |
| `perfil_editor.dart` | Crear y editar perfil (foto elegida + nombre) |
| `perfil_screen.dart` / `otro_perfil_screen.dart` | Tu perfil / el de otro participante |
| `memorias_screen.dart` | Memorias: tu semana día a día |
| `amigos_screen.dart` | Participantes: buscar y agregar |
| `remote_post_detalle.dart` | Detalle de un post (reacciones, comentarios) |
| `capture_flow.dart` | Captura (cámara dual + GPS); puente al código nativo |
| `capture_preview.dart` | Vista previa tras capturar: Publicar / Repetir / Cancelar |
| `captures.dart` | Modelo `Capture` y almacenamiento local |
| `notifications.dart` | Notificaciones locales y lectura de la agenda |
| `backend.dart` | Supabase: perfiles, capturas, amistades, estado, agenda |
| `secrets.dart` | Credenciales (no versionado, ver abajo) |
| `ajustes_screen.dart` | Ajustes y ayuda |
| `dev_screen.dart` | Trastienda (modo desarrollador) |
| `photo.dart` / `theme.dart` | Foto doble y placeholders / tema neutro de camuflaje |

El código nativo de cámara dual y escáner facial está en `ios/Runner/AppDelegate.swift`
(canal `rastro/multicam`).

## Configuración

### Credenciales de Supabase

No están en el repo. Copia la plantilla y rellénala:

```sh
cp lib/secrets.example.dart lib/secrets.dart
# edita lib/secrets.dart con supabaseUrl y supabaseKey (Supabase → Settings → API)
```

`lib/secrets.dart` está en `.gitignore`. Sin él la app no compila.

### Backend

Tablas: `perfiles`, `capturas`, `amistades`, `estado` (latido) y `agenda` (horarios de
notificación), más un bucket `capturas` para las fotos. El esquema está en
`supabase_schema.sql`.

## Compilar

> Mantén el proyecto **fuera de carpetas sincronizadas con iCloud** (Escritorio, Documentos).
> iCloud saca archivos del disco y los builds fallan con "Operation timed out". Un lugar como
> `~/dev/` evita el problema.

```sh
flutter pub get
```

### iOS

Requiere iOS 15 o superior. La cámara dual y el GPS no se prueban en simulador, así que usa un
iPhone con el Modo Desarrollador activo.

```sh
cd ios && pod install && cd ..
```

Con Xcode 26, `flutter run` falló por un problema del wrapper de Flutter con Xcode; compilar
con `xcodebuild` o archivar desde Xcode funciona:

```sh
cd ios
xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> \
  build/Build/Products/Release-iphoneos/Runner.app
```

**Para TestFlight:** abre `ios/Runner.xcworkspace` en Xcode, elige tu equipo en
*Signing & Capabilities* (target Runner y RunnerTests), y luego *Product → Archive* con destino
"Any iOS Device" y *Distribute App → App Store Connect*. Las notificaciones son locales, así
que no hacen falta capacidades extra ni APNs.

### Android

Necesita JDK 17 y el Android SDK (plataforma 35).

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=$HOME/Library/Android/sdk
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```

El APK queda firmado con la llave de debug: sirve para repartir por enlace a voluntarios, no
para publicar en Play Store. Solo incluye arm64, que cubre los teléfonos Android actuales.

## Estado y límites

- **Es una demo para un estudio cerrado**, con pocos participantes y consentimiento
  informado. El backend no tiene autenticación y sus reglas de acceso son permisivas, así que
  no uses este código con datos reales de terceros sin endurecerlo.
- Antes de abrirlo a más gente: autenticación anónima de Supabase, reglas RLS por usuario,
  bucket privado con URLs firmadas y rotar las credenciales. `supabase_hardening_v1.sql` es un
  primer paso (deja `capturas` en modo solo-agregar), pero no cierra la lectura.
- **Firma gratis (Personal Team)**: la app caduca a los 7 días y solo corre en dispositivos
  registrados. Para repartir a voluntarios hace falta TestFlight (cuenta de pago).
- Las notificaciones son locales: la hora debe estar definida de antemano en la agenda.
- La identificación en la entrevista es **manual, con confirmación visual** de la
  investigadora; no hay reconocimiento facial automático.

## Bibliotecas

`image_picker`, `geolocator`, `flutter_local_notifications`, `timezone`, `path_provider`,
`shared_preferences`, `google_fonts`, `supabase_flutter`.
