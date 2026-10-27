import 'package:flutter/material.dart';

import 'backend.dart';
import 'otro_perfil_screen.dart';
import 'photo.dart';
import 'theme.dart';

/// Lista de participantes reales (desde el backend): buscar y agregar amigos.
/// Lo que agregues aquí define tu feed de "Mis amigos".
class AmigosScreen extends StatefulWidget {
  const AmigosScreen({super.key});
  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

class _AmigosScreenState extends State<AmigosScreen> {
  String _q = '';
  String? _myDevice;
  List<Map<String, dynamic>> _gente = [];
  Set<String> _amigos = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await Backend.deviceId();
    final gente = await Backend.participantes();
    final amigos = await Backend.amigos();
    if (!mounted) return;
    setState(() {
      _myDevice = d;
      _gente = gente;
      _amigos = amigos;
      _cargando = false;
    });
  }

  String _nombre(Map<String, dynamic> p) =>
      (p['nombre'] ?? p['alias'] ?? 'anónimo') as String;

  Future<void> _toggle(Map<String, dynamic> p) async {
    final dev = p['device_id'] as String?;
    if (dev == null) return;
    final eraAmigo = _amigos.contains(dev);
    setState(() {
      if (eraAmigo) {
        _amigos.remove(dev);
      } else {
        _amigos.add(dev);
      }
    });
    if (eraAmigo) {
      await Backend.quitarAmigo(dev);
    } else {
      await Backend.agregarAmigo(dev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 900),
          backgroundColor: R.oliva,
          content: Text('agregaste a ${_nombre(p)}',
              style: R.mono(size: 12, color: R.verde)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final otros = _gente
        .where((p) => p['device_id'] != _myDevice)
        .where((p) => _nombre(p).toLowerCase().contains(_q))
        .toList();
    final amigos = otros.where((p) => _amigos.contains(p['device_id'])).toList();
    final resto = otros.where((p) => !_amigos.contains(p['device_id'])).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('AMIGOS', style: R.mono(size: 13, color: R.papel)),
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(color: R.verde, strokeWidth: 2))
          : RefreshIndicator(
              color: R.verde,
              backgroundColor: R.oliva,
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                children: [
                  TextField(
                    style: R.display(size: 15),
                    onChanged: (v) => setState(() => _q = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'buscar participante',
                      hintStyle: R.mono(size: 13, color: R.gris),
                      prefixIcon: const Icon(Icons.search, color: R.gris),
                      filled: true,
                      fillColor: R.oliva,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (amigos.isNotEmpty) ...[
                    Text('TUS AMIGOS · ${amigos.length}',
                        style: R.mono(size: 11, color: R.gris)),
                    const SizedBox(height: 8),
                    for (final p in amigos) _fila(p, esAmigo: true),
                    const SizedBox(height: 26),
                  ],
                  Text('PARTICIPANTES · ${resto.length}',
                      style: R.mono(size: 11, color: R.gris)),
                  const SizedBox(height: 8),
                  if (resto.isEmpty && amigos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          'aún no hay otros participantes.\nse irán sumando al experimento.',
                          textAlign: TextAlign.center,
                          style: R.mono(size: 12, color: R.gris),
                        ),
                      ),
                    ),
                  for (final p in resto) _fila(p, esAmigo: false),
                ],
              ),
            ),
    );
  }

  Widget _fila(Map<String, dynamic> p, {required bool esAmigo}) {
    final rostro = (p['avatar_url'] ?? p['rostro_url']) as String?;
    final alias = (p['alias'] ?? _nombre(p)) as String;
    void abrir() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtroPerfilScreen(alias: alias)));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: abrir,
            child: ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: GrainyPhoto(url: rostro, tone: _nombre(p).length % 4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: abrir,
              child: Text(_nombre(p),
                  style: R.display(size: 16, weight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () => _toggle(p),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: esAmigo ? Colors.transparent : R.verde,
                border: esAmigo ? Border.all(color: R.gris) : null,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(esAmigo ? 'AMIGOS' : 'AGREGAR',
                  style: R.mono(
                      size: 11, color: esAmigo ? R.gris : R.negro)),
            ),
          ),
        ],
      ),
    );
  }
}
