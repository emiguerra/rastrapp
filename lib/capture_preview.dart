import 'dart:io';

import 'package:flutter/material.dart';

import 'captures.dart';
import 'photo.dart';
import 'theme.dart';

/// Vista previa tras capturar: el usuario decide **Publicar** o **Repetir**.
/// Devuelve: true = publicar · false = repetir · null = cancelar.
class CapturePreview extends StatelessWidget {
  final Capture capture;
  const CapturePreview({super.key, required this.capture});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: R.negro,
      body: SafeArea(
        child: Column(
          children: [
            // Cancelar (descarta la toma).
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: R.papel, size: 28),
                onPressed: () => Navigator.of(context).pop(null),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: DualPhoto(
                    big: File(capture.imagePath),
                    small: capture.frontPath != null
                        ? File(capture.frontPath!)
                        : null,
                    radius: 20,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Row(
                children: [
                  // Repetir
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.refresh_rounded, color: R.papel),
                    label: Text('Repetir',
                        style: R.display(size: 16, weight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  // Publicar
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: R.papel,
                      foregroundColor: R.negro,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 34, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text('Publicar',
                        style: R.display(
                            size: 16,
                            weight: FontWeight.w800,
                            color: R.negro)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
