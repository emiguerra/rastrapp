import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'captures.dart';
import 'main.dart';
import 'notifications.dart';
import 'theme.dart';

/// Ajustes y ayuda: cómo funciona, estado de notificaciones, salir del estudio.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key});
  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  int _pendientes = 0;
  bool _notifOk = false;

  @override
  void initState() {
    super.initState();
    _estado();
  }

  Future<void> _estado() async {
    final p = await Notifications.pending();
    final ok = await Notifications.permisoActivo();
    if (mounted) setState(() {
      _pendientes = p.length;
      _notifOk = ok;
    });
  }

  Future<void> _salir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: R.oliva,
        title: Text('¿Salir del estudio?',
            style: R.display(size: 18, weight: FontWeight.w800)),
        content: Text(
            'Se borrarán tus datos de este teléfono y dejarás de recibir avisos. '
            'Esta acción no se puede deshacer.',
            style: R.display(size: 14, weight: FontWeight.w400, color: R.papel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancelar', style: R.mono(size: 13, color: R.gris)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('salir', style: R.mono(size: 13, color: R.verde)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Notifications.cancelAll();
    await CaptureStore.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text('AJUSTES', style: R.mono(size: 13, color: R.papel)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _seccion('¿CÓMO FUNCIONA?'),
          _texto(
              'Te avisamos una vez al día a una hora sorpresa. Cuando llega el aviso, '
              'captura tu momento: una foto de lo que ves y una tuya, al mismo tiempo. '
              'Al final de la semana conversamos contigo y te mostramos tu archivo.'),
          const SizedBox(height: 10),
          _texto('Para ver los momentos de los demás, primero publica el tuyo del día.'),
          const SizedBox(height: 26),
          _seccion('NOTIFICACIONES'),
          _fila(Icons.notifications_active_outlined, 'Permiso de avisos',
              _notifOk ? 'activo' : 'desactivado', _notifOk ? R.verde : R.gris),
          _fila(Icons.schedule, 'Avisos programados', '$_pendientes', R.papel),
          const SizedBox(height: 26),
          _seccion('PRIVACIDAD'),
          _texto(
              'Participas bajo un alias que tú elegiste. No usamos tu correo ni tu '
              'número. Puedes pedir que borremos tus datos al equipo de investigación.'),
          const SizedBox(height: 34),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _salir,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: R.gris.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ),
              child: Text('SALIR DEL ESTUDIO',
                  style: R.mono(size: 12, color: R.gris)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seccion(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: R.mono(size: 12, color: R.verde)),
      );

  Widget _texto(String t) => Text(t,
      style: R.display(size: 14, weight: FontWeight.w400, color: R.papel)
          .copyWith(height: 1.5));

  Widget _fila(IconData i, String label, String valor, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(i, color: R.gris, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: R.display(size: 15, weight: FontWeight.w500))),
            Text(valor, style: R.mono(size: 13, color: c)),
          ],
        ),
      );
}
