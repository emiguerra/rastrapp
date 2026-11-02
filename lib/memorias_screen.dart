import 'dart:io';

import 'package:flutter/material.dart';

import 'captures.dart';
import 'photo.dart';
import 'theme.dart';

/// Memorias (estilo BeReal): tu semana día a día, cada momento con su fecha y la
/// foto doble (toca para intercambiar frontal/trasera).
class MemoriasScreen extends StatefulWidget {
  const MemoriasScreen({super.key});
  @override
  State<MemoriasScreen> createState() => _MemoriasScreenState();
}

class _MemoriasScreenState extends State<MemoriasScreen> {
  late Future<List<Capture>> _future;

  @override
  void initState() {
    super.initState();
    _future = CaptureStore.all(); // ya viene ordenado (nuevas primero)
  }

  static const _dias = [
    'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
  ];
  static const _meses = [
    '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  String _fecha(DateTime d) =>
      '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month]}';
  String _hora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('MEMORIAS', style: R.mono(size: 13, color: R.papel)),
      ),
      body: FutureBuilder<List<Capture>>(
        future: _future,
        builder: (context, snap) {
          final caps = snap.data ?? const <Capture>[];
          if (caps.isEmpty) {
            return Center(
              child: Text(
                'aún no tienes memorias.\ncaptura tu primer momento.',
                textAlign: TextAlign.center,
                style: R.display(size: 15, weight: FontWeight.w400, color: R.gris),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: caps.length,
            separatorBuilder: (_, _) => const SizedBox(height: 28),
            itemBuilder: (_, i) {
              final c = caps[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fecha(c.takenAt),
                      style: R.display(size: 20, weight: FontWeight.w800)),
                  Text(_hora(c.takenAt),
                      style: R.mono(size: 12, color: R.gris)),
                  const SizedBox(height: 10),
                  DualPhoto(
                    big: File(c.imagePath),
                    small: c.frontPath != null ? File(c.frontPath!) : null,
                    radius: 18,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
