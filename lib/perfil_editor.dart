import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend.dart';
import 'main.dart';
import 'notifications.dart';
import 'theme.dart';

/// Crear / personalizar perfil: foto de perfil ELEGIDA por el usuario + nombre.
/// Es distinta del rostro biométrico. En onboarding entra al feed; en edición vuelve.
class PerfilEditor extends StatefulWidget {
  final bool onboarding;
  const PerfilEditor({super.key, this.onboarding = false});
  @override
  State<PerfilEditor> createState() => _PerfilEditorState();
}

class _PerfilEditorState extends State<PerfilEditor> {
  final _ctrl = TextEditingController();
  File? _foto;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    if (!widget.onboarding) {
      Backend.alias().then((a) {
        if (mounted) _ctrl.text = a == a.toLowerCase() ? a : a; // prefill
        if (mounted) setState(() {});
      });
      Backend.avatarLocal().then((p) {
        if (mounted && p != null && File(p).existsSync()) {
          setState(() => _foto = File(p));
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _valido => _ctrl.text.trim().length >= 2;

  Future<void> _elegirFoto() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: R.oliva,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: R.papel),
              title: Text('Elegir de la galería',
                  style: R.display(size: 16, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: R.papel),
              title: Text('Tomar una foto',
                  style: R.display(size: 16, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, imageQuality: 85);
    if (x != null && mounted) setState(() => _foto = File(x.path));
  }

  Future<void> _guardar() async {
    if (!_valido) return;
    setState(() => _cargando = true);
    await Backend.setUsername(_ctrl.text.trim());

    if (_foto != null) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final local = '${dir.path}/avatar_perfil.jpg';
        await _foto!.copy(local);
        await Backend.setAvatarLocal(local);
        await Backend.uploadAvatar(_foto!);
      } catch (_) {}
    }

    if (widget.onboarding) {
      await Notifications.requestPermissions();
      await Notifications.scheduleFromAgenda();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarded', true);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } else {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onboarding
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              title: Text('EDITAR PERFIL',
                  style: R.mono(size: 13, color: R.papel)),
            ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.onboarding) ...[
                const Align(
                    alignment: Alignment.centerLeft, child: Wordmark(size: 22)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('CREA TU PERFIL',
                      style: R.mono(size: 12, color: R.verde)),
                ),
              ],
              const Spacer(),
              // Foto de perfil
              GestureDetector(
                onTap: _elegirFoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: R.oliva,
                        border: Border.all(color: R.verde, width: 2),
                      ),
                      child: _foto != null
                          ? ClipOval(
                              child: Image.file(_foto!,
                                  fit: BoxFit.cover, width: 120, height: 120))
                          : const Icon(Icons.add_a_photo_outlined,
                              color: R.gris, size: 40),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: R.verde),
                      child: const Icon(Icons.edit, color: R.negro, size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text('toca para elegir tu foto de perfil',
                  style: R.mono(size: 11, color: R.gris)),
              const SizedBox(height: 30),
              TextField(
                controller: _ctrl,
                onChanged: (_) => setState(() {}),
                textAlign: TextAlign.center,
                style: R.display(size: 20, weight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'tu nombre o apodo',
                  hintStyle: R.mono(size: 15, color: R.gris),
                  filled: true,
                  fillColor: R.oliva,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: R.verde, width: 1.5),
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_valido && !_cargando) ? _guardar : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: R.verde,
                    foregroundColor: R.negro,
                    disabledBackgroundColor: R.oliva,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: R.verde))
                      : Text(widget.onboarding ? 'ENTRAR' : 'GUARDAR',
                          style: R.mono(
                              size: 14, color: _valido ? R.negro : R.gris)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
