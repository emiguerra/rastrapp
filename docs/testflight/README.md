# Subir rastrapp a TestFlight

La cuenta de Apple Developer es **individual**, así que los miembros invitados no pueden crear certificados de distribución desde Xcode. Para eso usamos una **llave de la API de App Store Connect**: con ella, Xcode crea el certificado y el perfil de distribución de forma automática.

- Team: `SBGFA6R968`
- Bundle ID: `xyz.piruetas.rastrapp`

## 1. Dueño de la cuenta: crear la llave (una sola vez)

1. Entra a [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Users and Access** → **Integrations** → **App Store Connect API** → **Team Keys**.
   - Si es la primera vez, aparece **Request Access**: acepta los términos.
2. **Generate API Key** (o **+**):
   - Nombre: por ejemplo `Emilia – TestFlight`
   - Acceso: **Admin**. Con un rol menor no se puede crear el certificado de distribución.
3. Anota el **Issuer ID** (arriba en la página) y el **Key ID** (en la fila de la llave).
4. Descarga `AuthKey_<KEYID>.p8`. **Solo se puede descargar una vez.**
5. Envía el `.p8` por un canal seguro (no por correo ni por un chat público), junto con el Issuer ID y el Key ID.

Cuando la llave ya no se necesite, revócala desde la misma página.

## 2. Quien sube: configurar (una sola vez)

1. Guarda la llave fuera del repositorio:

   ```bash
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
   ```

2. En la raíz del repositorio, copia la configuración de ejemplo y completa los valores:

   ```bash
   cp subir_testflight.env.ejemplo subir_testflight.env
   ```

   `subir_testflight.env` y los archivos `*.p8` están en `.gitignore`. Nunca los subas al repositorio.

## 3. Cada vez que subas una versión

1. Sube el número de build en `pubspec.yaml`. Por ejemplo, de `version: 1.0.0+1` a `version: 1.0.0+2`. Apple rechaza un número de build que ya se haya subido.
2. Desde la raíz del repositorio:

   ```bash
   sh subir_testflight.sh
   ```

3. El build aparece en App Store Connect → TestFlight cuando Apple termina de procesarlo (entre 5 y 30 minutos).

## Si algo falla

- El registro completo queda en `build/testflight/xcodebuild.log`.
- **"No encuentro la llave"**: revisa que el nombre del `.p8` coincida con `ID_LLAVE`, o define `RUTA_LLAVE` en `subir_testflight.env`.
- **Error de autenticación o permisos**: confirma que la llave tiene acceso **Admin** y que no fue revocada.
- **"The bundle version must be higher…"**: falta subir el `+N` en `pubspec.yaml`.
- **Error con `method` en `ExportOptions.plist`** (Xcode anterior a 15.3): cambia `app-store-connect` por `app-store` en `ios/ExportOptions.plist`.
