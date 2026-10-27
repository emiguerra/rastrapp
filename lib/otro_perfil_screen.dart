import 'package:flutter/material.dart';

import 'backend.dart';
import 'photo.dart';
import 'remote_post_detalle.dart';
import 'theme.dart';

/// Perfil (solo lectura) de otro participante: su foto, nombre y sus momentos.
class OtroPerfilScreen extends StatefulWidget {
  final String alias;
  const OtroPerfilScreen({super.key, required this.alias});
  @override
  State<OtroPerfilScreen> createState() => _OtroPerfilScreenState();
}

class _OtroPerfilScreenState extends State<OtroPerfilScreen> {
  Map<String, dynamic>? _perfil;
  List<RemoteCapture> _caps = [];
  Set<String> _amigos = {};
  String? _dispositivo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await Backend.perfilDe(widget.alias);
    final caps = await Backend.capturasDe(widget.alias);
    final amigos = await Backend.amigos();
    if (!mounted) return;
    setState(() {
      _perfil = p;
      _caps = caps;
      _dispositivo = p?['device_id'] as String?;
      _amigos = amigos;
      _cargando = false;
    });
  }

  bool get _esAmigo => _dispositivo != null && _amigos.contains(_dispositivo);

  Future<void> _toggleAmigo() async {
    final d = _dispositivo;
    if (d == null) return;
    final era = _esAmigo;
    setState(() => era ? _amigos.remove(d) : _amigos.add(d));
    if (era) {
      await Backend.quitarAmigo(d);
    } else {
      await Backend.agregarAmigo(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _perfil != null
        ? (_perfil!['avatar_url'] ?? _perfil!['rostro_url']) as String?
        : null;
    final dias = <String>{
      for (final c in _caps)
        '${c.takenAt.year}-${c.takenAt.month}-${c.takenAt.day}'
    }.length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(widget.alias.toUpperCase(),
            style: R.mono(size: 13, color: R.papel)),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: R.verde, strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: kTones[widget.alias.length % 4]),
                          border: Border.all(color: R.gris, width: 1.5),
                        ),
                        child: (avatar != null && avatar.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(avatar, fit: BoxFit.cover))
                            : const Icon(Icons.person_outline,
                                color: R.gris, size: 40),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.alias,
                          style:
                              R.display(size: 22, weight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _toggleAmigo,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _esAmigo ? R.oliva : R.verde,
                          foregroundColor: _esAmigo ? R.papel : R.negro,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 26, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999)),
                        ),
                        child: Text(_esAmigo ? 'AMIGOS ✓' : 'AGREGAR',
                            style: R.mono(
                                size: 12,
                                color: _esAmigo ? R.papel : R.negro)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('${_caps.length}', 'MOMENTOS'),
                    _stat('$dias', 'DÍAS'),
                  ],
                ),
                const SizedBox(height: 26),
                Text('SUS MOMENTOS', style: R.mono(size: 12, color: R.gris)),
                const SizedBox(height: 12),
                if (_caps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(
                      child: Text('aún no ha publicado momentos.',
                          style: R.mono(size: 12, color: R.gris)),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _caps.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 3 / 4,
                    ),
                    itemBuilder: (_, i) {
                      final c = _caps[i];
                      return GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => RemotePostDetalle(
                                  cap: c, avatarUrl: avatar)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GrainyPhoto(url: c.backUrl),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(v,
              style: R.display(
                  size: 24, weight: FontWeight.w900, color: R.verde)),
          const SizedBox(height: 2),
          Text(l, style: R.mono(size: 10, color: R.gris)),
        ],
      );
}
