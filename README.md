# rastrapp

App Flutter (Android) para tomar una foto y extraer sus metadatos, incluyendo la ubicación.

## Qué hace

- Toma una foto con la cámara o elige una de la galería.
- Lee todos los campos EXIF (cámara, fecha, exposición, etc.).
- Ubicación desde dos fuentes:
  - **EXIF de la foto** (si la app de cámara guarda GPS).
  - **GPS del teléfono** en el momento de tomar la foto (respaldo).
- Copiar coordenadas o todos los metadatos al portapapeles.

## Correr en el teléfono

1. Activar opciones de desarrollador y depuración USB en el teléfono.
2. Conectar por USB y ejecutar:

```sh
flutter run
```

O instalar el APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`.

## Notas

- Muchas apps de cámara solo guardan GPS en el EXIF si la opción "guardar ubicación" está activada en la cámara.
- El selector de fotos de Android 13+ elimina la ubicación del EXIF de las fotos de la galería.

## Bibliotecas

- [image_picker](https://pub.dev/packages/image_picker)
- [exif](https://pub.dev/packages/exif)
- [geolocator](https://pub.dev/packages/geolocator)
