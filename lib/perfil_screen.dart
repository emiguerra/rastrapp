import 'dart:io';

import 'package:flutter/material.dart';

import 'ajustes_screen.dart';
import 'backend.dart';
import 'captures.dart';
import 'perfil_editor.dart';
import 'photo.dart';
import 'theme.dart';

/// Perfil del usuario: su grilla de memorias (capturas reales) y su racha.
/// En modo usuario NO se muestra el GPS: eso se revela después, en el expediente.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});
  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  late Future<List<Capture>> _future;
  String _usuario = '';
  String? _avatar;

  @override
  void initState() {
    super.initState();
    _future = CaptureStore.all();
    Backend.alias().then((a) {
      if (mounted) setState(() => _usuario = a);
    });
    Backend.avatarLocal().then((p) {
      if (mounted) setState(() => _avatar = p);
    });
  }

  Future<void> _editar() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PerfilEditor()),
    );
    if (changed == true && mounted) {
      final a = await Backend.alias();
      final av = await Backend.avatarLocal();
      if (mounted) {
        setState(() {
          _usuario = a;
          _avatar = av;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('TU PERFIL', style: R.mono(size: 13, color: R.papel)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: R.papel),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AjustesScreen())),
          ),
        ],
      ),
      body: FutureBuilder<List<Capture>>(
        future: _future,
        builder: (context, snap) {
          final caps = snap.data ?? const <Capture>[];
          final dias = _diasUnicos(caps);
          return ListView(
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
                        gradient: const LinearGradient(
                            colors: [Color(0xFF2C2C2C), Color(0xFF17180F)]),
                        border: Border.all(color: R.verde, width: 2),
                      ),
                      child: (_avatar != null && File(_avatar!).existsSync())
                          ? ClipOval(
                              child: Image.file(File(_avatar!),
                                  fit: BoxFit.cover, width: 92, height: 92))
                          : caps.isNotEmpty
                              ? ClipOval(
                                  child: Image.file(File(caps.first.imagePath),
                                      fit: BoxFit.cover))
                              : const Icon(Icons.person_outline,
                                  color: R.gris, size: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(_usuario.isEmpty ? 'tú' : _usuario,
                        style: R.display(size: 22, weight: FontWeight.w900)),
                    Text(_usuario.isEmpty ? '' : '@$_usuario',
                        style: R.mono(size: 12, color: R.gris)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _editar,
                      icon: const Icon(Icons.edit, size: 16, color: R.verde),
                      label: Text('EDITAR PERFIL',
                          style: R.mono(size: 11, color: R.verde)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: R.verde, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  _Stat(value: '${caps.length}', label: 'MOMENTOS'),
                  _Stat(value: '$dias', label: 'DÍAS'),
                  _Stat(value: '🔥 $dias', label: 'RACHA'),
                ],
              ),
              const SizedBox(height: 26),
              Text('TUS MEMORIAS', style: R.mono(size: 12, color: R.gris)),
              const SizedBox(height: 12),
              if (caps.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text('aún no tienes memorias.\ncaptura tu primer momento.',
                        textAlign: TextAlign.center,
                        style: R.mono(size: 12, color: R.gris)),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: caps.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 3 / 4,
                  ),
                  itemBuilder: (_, i) => _MemoryTile(caps[i]),
                ),
            ],
          );
        },
      ),
    );
  }

  int _diasUnicos(List<Capture> caps) {
    final set = <String>{};
    for (final c in caps) {
      set.add('${c.takenAt.year}-${c.takenAt.month}-${c.takenAt.day}');
    }
    return set.length;
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: R.display(size: 24, weight: FontWeight.w900, color: R.verde)),
            const SizedBox(height: 2),
            Text(label, style: R.mono(size: 10, color: R.gris)),
          ],
        ),
      );
}

class _MemoryTile extends StatelessWidget {
  final Capture c;
  const _MemoryTile(this.c);
  @override
  Widget build(BuildContext context) {
    final front = c.frontPath != null ? File(c.frontPath!) : null;
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DualPhoto(big: File(c.imagePath), small: front, radius: 18),
              const SizedBox(height: 10),
              Text(_fecha(c.takenAt), style: R.mono(size: 12, color: R.papel)),
            ],
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(child: GrainyPhoto(file: File(c.imagePath))),
            if (front != null)
              Positioned(
                top: 5,
                left: 5,
                child: Container(
                  width: 30,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: GrainyPhoto(file: front),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fecha(DateTime d) {
    const meses = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${meses[d.month]} · $hh:$mm';
  }
}
