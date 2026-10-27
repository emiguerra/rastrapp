import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'captures.dart';
import 'notifications.dart';

/// Modo desarrollador: la trastienda. Muestra lo que se extrajo (GPS, hora) de
/// cada captura y controla las notificaciones. NO es visible para el usuario.
class DevScreen extends StatefulWidget {
  const DevScreen({super.key});
  @override
  State<DevScreen> createState() => _DevScreenState();
}

class _DevScreenState extends State<DevScreen> {
  late Future<List<Capture>> _future;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _future = CaptureStore.all();
    _refreshPending();
  }

  Future<void> _refreshPending() async {
    final p = await Notifications.pending();
    if (mounted) setState(() => _pending = p.length);
  }

  void _reload() => setState(() => _future = CaptureStore.all());

  Future<void> _export() async {
    final json = await CaptureStore.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('JSON copiado al portapapeles')));
  }

  Future<void> _clear() async {
    await CaptureStore.clear();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trastienda · dev'),
        backgroundColor: const Color(0xFF14202E),
      ),
      body: FutureBuilder<List<Capture>>(
        future: _future,
        builder: (context, snap) {
          final caps = snap.data ?? const <Capture>[];
          final conGps = caps.where((c) => c.hasGps).length;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFF14202E),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${caps.length} capturas · $conGps con GPS',
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 13)),
                    Text('$_pending notificaciones programadas',
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: Colors.white54)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule, size: 18),
                          label: const Text('Programar 7 días'),
                          onPressed: () async {
                            await Notifications.scheduleFromAgenda();
                            await _refreshPending();
                          },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.copy_all, size: 18),
                          label: const Text('Exportar JSON'),
                          onPressed: caps.isEmpty ? null : _export,
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Borrar todo'),
                          onPressed: caps.isEmpty ? null : _clear,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: caps.isEmpty
                    ? const Center(
                        child: Text('Sin capturas todavía',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: caps.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) => _DevRow(caps[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DevRow extends StatelessWidget {
  final Capture c;
  const _DevRow(this.c);

  @override
  Widget build(BuildContext context) {
    final file = File(c.imagePath);
    final gps = c.hasGps
        ? '${c.lat!.toStringAsFixed(6)}, ${c.lng!.toStringAsFixed(6)}'
            '  ±${c.accuracy?.toStringAsFixed(0) ?? '?'} m'
        : 'sin GPS';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 52,
          height: 52,
          child: file.existsSync()
              ? Image.file(file, fit: BoxFit.cover)
              : Container(color: Colors.white10),
        ),
      ),
      title: Text(gps,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: c.hasGps ? Colors.lightBlueAccent : Colors.redAccent)),
      subtitle: Text(
        c.takenAt.toString().substring(0, 19),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    );
  }
}
