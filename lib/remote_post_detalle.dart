import 'package:flutter/material.dart';

import 'backend.dart';
import 'photo.dart';
import 'theme.dart';

/// Detalle de un post (unificado para todos). Foto grande + reacciones +
/// comentarios. Reacciones y comentarios son REALES: se guardan en el backend y
/// los ven todas las participantes.
class RemotePostDetalle extends StatefulWidget {
  final RemoteCapture cap;
  final String? avatarUrl;
  const RemotePostDetalle({super.key, required this.cap, this.avatarUrl});

  @override
  State<RemotePostDetalle> createState() => _RemotePostDetalleState();
}

class _RemotePostDetalleState extends State<RemotePostDetalle> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _comentarios = [];
  Map<String, int> _conteo = {}; // emoji -> cuántas reacciones
  String? _miReaccion;
  String? _miDevice;
  bool _enviando = false;

  static const _emojis = ['🔥', '😂', '😮', '💚', '👀'];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    _miDevice = await Backend.deviceId();
    await _recargar();
  }

  Future<void> _recargar() async {
    final id = widget.cap.id;
    if (id == null) return;
    final coms = await Backend.comentariosDe(id);
    final reacs = await Backend.reaccionesDe(id);
    final conteo = <String, int>{};
    String? mia;
    for (final r in reacs) {
      final e = r['emoji'] as String?;
      if (e == null) continue;
      conteo[e] = (conteo[e] ?? 0) + 1;
      if (r['device_id'] == _miDevice) mia = e;
    }
    if (!mounted) return;
    setState(() {
      _comentarios = coms;
      _conteo = conteo;
      _miReaccion = mia;
    });
  }

  Future<void> _enviar() async {
    final t = _ctrl.text.trim();
    final id = widget.cap.id;
    if (t.isEmpty || id == null || _enviando) return;
    setState(() => _enviando = true);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    await Backend.comentar(id, t);
    await _recargar();
    if (mounted) setState(() => _enviando = false);
  }

  Future<void> _reaccionar(String e) async {
    final id = widget.cap.id;
    if (id == null) return;
    final nueva = _miReaccion == e ? null : e; // toca la misma = la quita
    setState(() {
      // actualización optimista del conteo
      if (_miReaccion != null) {
        _conteo[_miReaccion!] = ((_conteo[_miReaccion!] ?? 1) - 1).clamp(0, 1 << 30);
      }
      if (nueva != null) _conteo[nueva] = (_conteo[nueva] ?? 0) + 1;
      _miReaccion = nueva;
    });
    await Backend.reaccionar(id, nueva);
    await _recargar();
  }

  String _rel(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
    if (d.inHours < 24) return 'hace ${d.inHours} h';
    return 'hace ${d.inDays} d';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cap;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: kTones[c.alias.length % 4]),
                border: Border.all(color: R.gris, width: 1),
              ),
              child: (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(widget.avatarUrl!, fit: BoxFit.cover))
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.alias,
                    style: R.display(size: 16, weight: FontWeight.w800)),
                Text(_rel(c.takenAt).toUpperCase(),
                    style: R.mono(size: 10, color: R.gris)),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          DualPhoto(bigUrl: c.backUrl, smallUrl: c.frontUrl, tone: 1),
          const SizedBox(height: 18),
          Text('REACCIONAR', style: R.mono(size: 11, color: R.gris)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in _emojis)
                GestureDetector(
                  onTap: () => _reaccionar(e),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _miReaccion == e
                              ? R.verde.withValues(alpha: 0.2)
                              : R.oliva,
                          border: Border.all(
                              color: _miReaccion == e
                                  ? R.verde
                                  : R.gris.withValues(alpha: 0.4),
                              width: _miReaccion == e ? 2 : 1),
                        ),
                        child: Center(
                            child:
                                Text(e, style: const TextStyle(fontSize: 24))),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (_conteo[e] ?? 0) > 0 ? '${_conteo[e]}' : '',
                        style: R.mono(size: 11, color: R.gris),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text('COMENTARIOS · ${_comentarios.length}',
              style: R.mono(size: 11, color: R.gris)),
          const SizedBox(height: 12),
          if (_comentarios.isEmpty)
            Text('sé el primero en comentar',
                style: R.mono(size: 12, color: R.gris)),
          for (final com in _comentarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                      radius: 15,
                      backgroundColor: R.oliva,
                      child: Icon(Icons.person, size: 16, color: R.verde)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((com['alias'] ?? 'anónimo') as String,
                            style:
                                R.display(size: 13, weight: FontWeight.w700)),
                        Text((com['texto'] ?? '') as String,
                            style:
                                R.display(size: 14, weight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: R.display(size: 15),
                  enabled: !_enviando,
                  decoration: InputDecoration(
                    hintText: 'agrega un comentario…',
                    hintStyle: R.mono(size: 13, color: R.gris),
                    filled: true,
                    fillColor: R.oliva,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _enviar,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: R.verde),
                  child: const Icon(Icons.arrow_upward_rounded,
                      color: R.negro, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
