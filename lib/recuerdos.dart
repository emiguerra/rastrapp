import 'dart:math';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';

/// MOTOR DE "RECUERDOS" (función de participante).
///
/// Lee la galería EN el teléfono, extrae de cada foto su fecha y la ubicación
/// del EXIF, agrupa las coordenadas en lugares (casa / trabajo-estudio / tercer
/// lugar, igual que el motor de geo de Colab) y elige 5 fotos representativas
/// para la revelación. Al backend solo suben: el resumen (conteo, fechas,
/// lugares) y esas 5 fotos (a un bucket PRIVADO). La galería completa nunca sale
/// del teléfono.
///
/// A diferencia de `dev_galeria_screen.dart` (demo local, dev-only, no sube),
/// este camino sí es para builds de participante — y por eso requiere el permiso
/// en el manifest de producción, que es el switch que se activa a conciencia.

/// Una foto leída de la galería, con lo que la app puede saber de ella.
class RecuerdoFoto {
  final AssetEntity asset;
  final DateTime fecha;
  final double? lat;
  final double? lng;
  String label; // CASA / TRABAJO-ESTUDIO / tercer lugar / '' si no tiene geo

  RecuerdoFoto(this.asset, this.fecha, this.lat, this.lng, [this.label = '']);

  bool get tieneGps => lat != null && lng != null;

  /// Bytes para subir las 5 elegidas (reescaladas, no a resolución completa).
  Future<Uint8List?> bytes() =>
      asset.thumbnailDataWithSize(const ThumbnailSize(1440, 1440), quality: 88);
}

/// Un lugar recurrente reconstruido desde las coordenadas de las fotos.
class Lugar {
  String label;
  double lat;
  double lng;
  int n;
  final List<RecuerdoFoto> fotos;
  Lugar(this.label, this.lat, this.lng, this.n, this.fotos);

  Map<String, dynamic> toJson() =>
      {'label': label, 'lat': lat, 'lng': lng, 'n': n};
}

/// El resultado del escaneo: lo que se revela y lo que se sube.
class RecuerdosResumen {
  final int total; // nº de fotos leídas
  final int conGps; // cuántas traían ubicación
  final DateTime? desde; // foto más antigua
  final DateTime? hasta; // foto más reciente
  final List<Lugar> lugares; // clusters etiquetados
  final List<RecuerdoFoto> seleccion; // las 5 para la revelación

  RecuerdosResumen({
    required this.total,
    required this.conGps,
    required this.desde,
    required this.hasta,
    required this.lugares,
    required this.seleccion,
  });

  List<Map<String, dynamic>> lugaresJson() =>
      lugares.map((l) => l.toJson()).toList();
}

/// Fotos de una misma fecha en un año anterior («un día como hoy»).
class RecuerdoDia {
  final int anio;
  final List<AssetEntity> fotos;
  RecuerdoDia(this.anio, this.fotos);
}

/// Nivel de acceso a la galería que concedió la persona.
enum AccesoGaleria { completo, limitado, denegado }

class MotorRecuerdos {
  /// Pide EXPLÍCITAMENTE acceso completo a la galería. Si la persona elige
  /// «fotos seleccionadas» el resultado es [AccesoGaleria.limitado] y no sirve:
  /// la función necesita todas las fotos para reconstruir el recorrido.
  static Future<AccesoGaleria> pedirAcceso() async {
    final ps = await PhotoManager.requestPermissionExtend(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    if (ps == PermissionState.authorized) return AccesoGaleria.completo;
    if (ps == PermissionState.limited) return AccesoGaleria.limitado;
    return AccesoGaleria.denegado;
  }

  /// Estado actual del permiso, SIN mostrar el diálogo del sistema.
  static Future<AccesoGaleria> accesoActual() async {
    final ps = await PhotoManager.getPermissionState(
      requestOption: const PermissionRequestOption(
        iosAccessLevel: IosAccessLevel.readWrite,
      ),
    );
    if (ps == PermissionState.authorized) return AccesoGaleria.completo;
    if (ps == PermissionState.limited) return AccesoGaleria.limitado;
    return AccesoGaleria.denegado;
  }

  /// «Un día como hoy»: fotos de esta fecha (±3 días) en años anteriores, leídas
  /// en el teléfono. Excluye las ya elegidas para la revelación: lo que se le
  /// muestra a la persona NUNCA incluye esas cinco.
  static Future<List<RecuerdoDia>> delDia({
    Set<String> excluir = const {},
    DateTime? hoy,
  }) async {
    final now = hoy ?? DateTime.now();
    final out = <RecuerdoDia>[];
    for (var k = 1; k <= 8; k++) {
      final centro = DateTime(now.year - k, now.month, now.day);
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: FilterOptionGroup(
          createTimeCond: DateTimeCond(
            min: centro.subtract(const Duration(days: 3)),
            max: centro.add(const Duration(days: 4)),
          ),
        ),
      );
      if (paths.isEmpty) continue;
      final lista = await paths.first.getAssetListRange(start: 0, end: 12);
      final f = lista.where((a) => !excluir.contains(a.id)).take(4).toList();
      if (f.isNotEmpty) out.add(RecuerdoDia(now.year - k, f));
    }
    return out;
  }

  /// Escanea la galería. Quien llama debe haber obtenido acceso completo antes
  /// con [pedirAcceso]; si no hay acceso devuelve null.
  static Future<RecuerdosResumen?> escanear({
    void Function(int leidas, int total)? onProgreso,
  }) async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (ps != PermissionState.authorized) return null;

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );
    if (paths.isEmpty) {
      return RecuerdosResumen(
          total: 0,
          conGps: 0,
          desde: null,
          hasta: null,
          lugares: const [],
          seleccion: const []);
    }

    final all = paths.first;
    final total = await all.assetCountAsync;
    final fotos = <RecuerdoFoto>[];

    const pageSize = 80;
    final pages = (total / pageSize).ceil();
    for (var p = 0; p < pages; p++) {
      final batch = await all.getAssetListPaged(page: p, size: pageSize);
      for (final a in batch) {
        final ll = await a.latlngAsync();
        double? lat = ll?.latitude ?? a.latitude;
        double? lng = ll?.longitude ?? a.longitude;
        if (lat == 0) lat = null;
        if (lng == 0) lng = null;
        fotos.add(RecuerdoFoto(a, a.createDateTime, lat, lng));
      }
      onProgreso?.call(fotos.length, total);
    }

    return _procesar(fotos, total);
  }

  // ── Procesamiento: clusters + etiquetas + selección de 5 ──────────────────
  static RecuerdosResumen _procesar(List<RecuerdoFoto> fotos, int total) {
    fotos.sort((x, y) => x.fecha.compareTo(y.fecha));
    final conGeo = fotos.where((f) => f.tieneGps).toList();

    final lugares = _clusterizar(conGeo);
    lugares.sort((x, y) => y.n.compareTo(x.n)); // más visitados primero

    // Etiqueta cada foto con el label de su cluster (para la revelación).
    for (final l in lugares) {
      for (final f in l.fotos) {
        f.label = l.label;
      }
    }

    final seleccion = _elegirCinco(lugares, fotos, conGeo);

    return RecuerdosResumen(
      total: total,
      conGps: conGeo.length,
      desde: fotos.isNotEmpty ? fotos.first.fecha : null,
      hasta: fotos.isNotEmpty ? fotos.last.fecha : null,
      lugares: lugares,
      seleccion: seleccion,
    );
  }

  /// Agrupación voraz por cercanía (~80 m): barato y suficiente para elegir 5.
  static List<Lugar> _clusterizar(List<RecuerdoFoto> conGeo) {
    const radio = 80.0; // metros
    final clusters = <Lugar>[];
    for (final f in conGeo) {
      Lugar? cercano;
      for (final c in clusters) {
        if (_distM(c.lat, c.lng, f.lat!, f.lng!) <= radio) {
          cercano = c;
          break;
        }
      }
      if (cercano == null) {
        clusters.add(Lugar('', f.lat!, f.lng!, 1, [f]));
      } else {
        // recalcula el centroide de forma incremental
        cercano.lat = (cercano.lat * cercano.n + f.lat!) / (cercano.n + 1);
        cercano.lng = (cercano.lng * cercano.n + f.lng!) / (cercano.n + 1);
        cercano.n += 1;
        cercano.fotos.add(f);
      }
    }
    // Solo lugares recurrentes (2+ fotos) y etiquetado por franja horaria.
    final recurrentes = clusters.where((c) => c.n >= 2).toList();
    for (final c in recurrentes) {
      c.fotos.sort((a, b) => a.fecha.compareTo(b.fecha));
      _etiquetar(c);
    }
    return recurrentes;
  }

  /// Casa / trabajo-estudio / tercer lugar, por la hora dominante de sus fotos.
  static void _etiquetar(Lugar c) {
    final horas = c.fotos.map((f) => f.fecha).toList();
    final noche = horas
            .where((d) => d.hour >= 22 || d.hour <= 6)
            .length /
        horas.length;
    final semana = horas
            .where((d) => d.weekday <= 5 && d.hour >= 8 && d.hour <= 19)
            .length /
        horas.length;
    if (noche >= 0.5) {
      c.label = 'CASA';
    } else if (semana >= 0.5) {
      c.label = 'TRABAJO-ESTUDIO';
    } else {
      c.label = 'tercer lugar';
    }
  }

  /// Elige 5: casa · trabajo · tercer lugar · la más antigua · la más reciente.
  static List<RecuerdoFoto> _elegirCinco(
      List<Lugar> lugares, List<RecuerdoFoto> todas, List<RecuerdoFoto> conGeo) {
    final sel = <RecuerdoFoto>[];
    final ids = <String>{};
    void add(RecuerdoFoto? f) {
      if (f == null || ids.contains(f.asset.id)) return;
      ids.add(f.asset.id);
      sel.add(f);
    }

    Lugar? porLabel(String l) {
      for (final c in lugares) {
        if (c.label == l) return c;
      }
      return null;
    }

    // Representante de un lugar = su foto más reciente.
    RecuerdoFoto? rep(Lugar? c) => c?.fotos.last;

    add(rep(porLabel('CASA')));
    add(rep(porLabel('TRABAJO-ESTUDIO')));
    add(rep(porLabel('tercer lugar')));
    if (conGeo.isNotEmpty) {
      add(conGeo.first); // más antigua con GPS
      add(conGeo.last); // más reciente con GPS
    }

    // Rellenar hasta 5 con los lugares más grandes y, si falta, cualquier foto.
    for (final c in lugares) {
      if (sel.length >= 5) break;
      add(c.fotos.last);
    }
    for (final f in todas.reversed) {
      if (sel.length >= 5) break;
      add(f);
    }
    return sel.take(5).toList();
  }

  static double _distM(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    final dLat = (la2 - la1) * pi / 180;
    final dLon = (lo2 - lo1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(la1 * pi / 180) * cos(la2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}
