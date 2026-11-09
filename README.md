# rastrapp

Aplicación del proyecto de tesis rastro (Diseño, UDP), hecha en Flutter para iOS y Android.

Por fuera es una red social de fotos parecida a BeReal: una foto al día, a una hora sorpresa. Por dentro guarda el lugar exacto donde se tomó cada foto. La app nunca le muestra ese dato a quien la usa; se revela una semana después, en una entrevista, impreso en papel térmico. El proyecto es un ejercicio de diseño crítico sobre la resignación informada frente a la vigilancia algorítmica.

## Camuflaje

La app debe verse como una red social cualquiera: fondo negro, texto blanco, grises neutros y tipografía sans. La identidad gráfica de rastro (verde ácido, tipografía pixel, grano de spray) no se usa aquí. Se reserva para la revelación: el panel de la investigadora, el expediente impreso y la instalación.

Esto no es una decisión estética. El estudio depende de que las personas crean que usan una red social común, y una marca llamativa avisaría que hay algo más y alteraría lo que se quiere medir.

## Estructura de carpetas

```text
lib/                  código Dart de la app
ios/Runner/           proyecto de iOS; AppDelegate.swift tiene la cámara dual y el escáner facial
android/              proyecto de Android
assets/               imágenes de la app
supabase_schema.sql   esquema de la base de datos
supabase_hardening_v1.sql   primer paso de endurecimiento, opcional
```

Los archivos de `lib/` se dividen así:

```text
main.dart                 barra inferior (Feed, Amigos, Perfil), feed y onboarding
terminos_screen.dart      términos y condiciones
biometria_screen.dart     registro facial
perfil_editor.dart        crear y editar perfil
perfil_screen.dart        tu perfil
otro_perfil_screen.dart   perfil de otro participante
memorias_screen.dart      tu semana, día a día
amigos_screen.dart        lista de participantes
remote_post_detalle.dart  detalle de un post
capture_flow.dart         captura de foto y GPS, y conexión con el código nativo
capture_preview.dart      vista previa tras capturar
captures.dart             modelo de captura y almacenamiento local
notifications.dart        notificaciones locales y lectura de la agenda
backend.dart              conexión con Supabase
secrets.dart              credenciales, no versionado
ajustes_screen.dart       ajustes y ayuda
dev_screen.dart           trastienda del modo desarrollador
photo.dart                foto doble y placeholders
theme.dart                tema neutro
```

## Flujo de la app

Al abrirla por primera vez se pasa por el inicio, los términos y condiciones, el registro facial y la creación del perfil, en ese orden. El rostro del registro es la llave con la que la investigadora reconoce a cada persona en la entrevista, y es distinto de la foto de perfil que cada una elige.

En el registro facial la persona mueve la cabeza en círculo y los segmentos de un anillo se van llenando, usando la detección de rostros de Vision. La vista previa va en espejo para que el movimiento se sienta natural, pero la foto que se guarda va sin espejo.

Para capturar, la app toma dos fotos al mismo tiempo, una con la cámara trasera y otra con la frontal, y guarda el GPS en ese instante. Después muestra una vista previa con tres opciones: publicar, repetir o cancelar. Nada se guarda hasta publicar. En la foto doble, tocar el recuadro chico intercambia la frontal con la trasera.

El feed muestra las publicaciones de otros participantes, y para verlas hay que publicar primero la propia. En Amigos se puede buscar y agregar a otros participantes, y tocar un nombre abre su perfil. En el perfil, el ícono de calendario abre las Memorias, que muestran la semana día a día. La racha cuenta días consecutivos y se corta si pasa un día sin captura.

Las notificaciones son locales, una por día, a la hora que define la tabla `agenda` en Supabase, con hasta 20 minutos de variación al azar. No hay servidor de push. Cada vez que se abre la app, esta registra su último acceso, el estado de los permisos y la cantidad de capturas, para poder medir qué pasa después de la revelación.

El modo desarrollador se activa manteniendo presionado el nombre `rastro.` en la parte de arriba del feed. Muestra el GPS de cada captura y permite reprogramar las notificaciones y exportar los datos en JSON.

## iOS y Android

El código es el mismo en las dos plataformas, pero las funciones nativas de iOS tienen un respaldo en Android. En Android la cámara toma una sola foto con la cámara del sistema, y el registro facial es una selfie simple. El GPS, las comunas y el expediente funcionan igual en ambas.

## Credenciales de Supabase

Las credenciales no están en el repositorio. Para correr la app hay que copiar la plantilla y completarla con la URL y la llave del proyecto (en Supabase, en Settings, API):

```sh
cp lib/secrets.example.dart lib/secrets.dart
```

El archivo `lib/secrets.dart` está en `.gitignore`. Sin él la app no compila.

## Base de datos

Las tablas son `perfiles`, `capturas`, `amistades`, `estado` (el latido de cada app) y `agenda` (los horarios de las notificaciones), más un bucket de almacenamiento llamado `capturas` para las fotos. Todo se crea con `supabase_schema.sql`.

## Compilar

El proyecto debe estar fuera de carpetas sincronizadas con iCloud, como el Escritorio o Documentos. iCloud saca archivos del disco y los builds fallan con `Operation timed out`. Una carpeta como `~/dev/` evita el problema.

```sh
flutter pub get
```

### iOS

Requiere iOS 15 o superior. La cámara dual y el GPS no funcionan en el simulador, así que hay que usar un iPhone con el Modo Desarrollador activado.

```sh
cd ios && pod install && cd ..
```

Con Xcode 26, `flutter run` falló por un problema entre Flutter y Xcode. Compilar con `xcodebuild` o archivar desde Xcode sí funciona:

```sh
cd ios
xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath build -allowProvisioningUpdates build
xcrun devicectl device install app --device <UDID> \
  build/Build/Products/Release-iphoneos/Runner.app
```

### Android

Necesita JDK 17 y el Android SDK con la plataforma 35.

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export ANDROID_HOME=$HOME/Library/Android/sdk
flutter build apk --release --target-platform android-arm64
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`. Solo incluye arm64, que cubre los teléfonos Android actuales, y queda firmado con la llave de debug: sirve para compartirlo por un enlace, no para publicarlo en Play Store.

## Distribución

Una app firmada con una cuenta gratuita de Apple caduca a los 7 días y solo corre en los dispositivos registrados. Para repartirla a más personas hay que subirla a TestFlight con una cuenta de pago.

Para eso se abre `ios/Runner.xcworkspace` en Xcode, se elige el equipo en Signing & Capabilities (tanto en el target Runner como en RunnerTests) y se usa Product, Archive con destino Any iOS Device, y luego Distribute App, App Store Connect. Las notificaciones son locales, por lo que no hace falta ninguna capacidad extra ni APNs.

## Herramientas de la investigadora

Fuera de este repositorio hay un panel web y un script de impresión. No se versionan porque leen rostros y ubicaciones de los participantes. El panel muestra el mapa, las comunas, los patrones de rutina, la malla biométrica y el seguimiento posterior a la revelación. El script imprime el expediente de cada persona en una impresora térmica Sewoo SLK-TS400, por USB y con comandos ESC/POS.

La identificación de cada persona en la entrevista es manual: la investigadora compara el rostro del registro con la persona que tiene delante y confirma el alias. No hay reconocimiento facial automático.

## Estado

Es una demo para un estudio cerrado, con pocos participantes y consentimiento informado. El backend no tiene autenticación y sus reglas de acceso son permisivas, por lo que no conviene usar este código con datos reales de terceros sin endurecerlo.

Antes de abrirlo a más gente hace falta activar la autenticación anónima de Supabase, escribir reglas RLS por usuario, hacer privado el bucket con URLs firmadas y rotar las credenciales. `supabase_hardening_v1.sql` es un primer paso, porque deja la tabla `capturas` en modo solo agregar, pero no cierra la lectura.

## Bibliotecas

`image_picker`, `geolocator`, `flutter_local_notifications`, `timezone`, `path_provider`, `shared_preferences`, `google_fonts` y `supabase_flutter`.
