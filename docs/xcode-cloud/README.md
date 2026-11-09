# Xcode Cloud

Xcode Cloud compila rastrapp en los servidores de Apple y sube cada build a TestFlight, sin llaves `.p8` en nuestras máquinas. Reemplaza a `subir_testflight.sh` (ver `docs/testflight/README.md`), que sigue sirviendo como alternativa manual.

- Repositorio: `github.com/rastrapp/rastrapp` (organización)
- Team: `SBGFA6R968`
- Bundle ID: `xyz.piruetas.rastrapp`
- Script de preparación: `ios/ci_scripts/ci_post_clone.sh`

## Cómo funciona

Como es una app Flutter, antes de compilar, `ci_post_clone.sh`:

1. instala Flutter (la misma versión que usamos localmente),
2. genera `lib/secrets.dart` a partir de las variables `SUPABASE_URL` y `SUPABASE_LLAVE`,
3. corre `flutter pub get` y fija el número de build con `CI_BUILD_NUMBER`,
4. instala CocoaPods y corre `pod install`.

El número de build lo asigna Xcode Cloud, así que ya no hace falta subir el `+N` de `pubspec.yaml` en cada envío. La versión visible (`1.0.0`) sí se sigue cambiando en `pubspec.yaml`.

## Configuración (una sola vez)

1. **Acceso de GitHub a la organización.** Al crear el workflow, Xcode pide instalar la app *Xcode Cloud* en GitHub. Hay que instalarla en la organización **rastrapp** (no en una cuenta personal) y darle acceso al repositorio `rastrapp`. Esto lo debe aprobar alguien con permisos de dueño en la organización.
2. **Crear el workflow.** Abre `ios/Runner.xcworkspace` en Xcode → *Integrate* → *Create Workflow…* → elige la app `Runner`. La persona debe tener el rol *Admin* o *App Manager* en App Store Connect.
3. **Editar el workflow:**
   - **Environment:** la última versión estable de Xcode y de macOS.
   - **Environment Variables:** agrega `SUPABASE_URL` y `SUPABASE_LLAVE` con los valores de `lib/secrets.dart`. Marca ambas como **Secret**.
   - **Start Conditions:** *Branch Changes* en `main` (o solo *Manual Start*, si preferimos decidir cuándo subir).
   - **Actions:** *Archive* → plataforma iOS, esquema `Runner`, distribución **TestFlight (Internal Testing Only)**.
   - **Post-Actions:** *TestFlight Internal Testing* → elige el grupo de testers.
4. **Número de build inicial.** Ya subimos builds a mano, así que en App Store Connect → la app → *Xcode Cloud* → *Settings* → *Build Number* hay que fijar el siguiente número en uno mayor que el último build subido a TestFlight.
5. Inicia un primer build con *Start Build* y revisa el registro de `ci_post_clone.sh` si algo falla.

## Si algo falla

- **"Falta la variable SUPABASE_…"**: no se agregaron las variables en el workflow (paso 3).
- **No encuentra el repositorio**: la app de Xcode Cloud en GitHub no tiene acceso a la organización `rastrapp` (paso 1).
- **"The bundle version must be higher…"**: sube el número inicial (paso 4).
- **Error de Flutter o de Dart**: actualiza `VERSION_FLUTTER` en `ci_post_clone.sh` a la versión que usamos localmente (`flutter --version`).
