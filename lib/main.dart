import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ajustes_screen.dart';
import 'amigos_screen.dart';
import 'backend.dart';
import 'capture_flow.dart';
import 'captures.dart';
import 'dev_screen.dart';
import 'notifications.dart';
import 'otro_perfil_screen.dart';
import 'perfil_screen.dart';
import 'photo.dart';
import 'remote_post_detalle.dart';
import 'terminos_screen.dart';
import 'theme.dart';

const String kAppName = 'rastro';

/// Modo de la app. En modo usuario no se ve nada de la trastienda.
final ValueNotifier<bool> devMode = ValueNotifier<bool>(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  await Notifications.init();
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;
  runApp(RastroApp(onboarded: onboarded));
}

class RastroApp extends StatelessWidget {
  final bool onboarded;
  const RastroApp({super.key, required this.onboarded});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: R.theme(),
      home: onboarded ? const MainShell() : const OnboardingScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Onboarding

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  void _comenzar() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TerminosScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.45,
            child: Image.asset('assets/spray.png',
                width: 420, fit: BoxFit.contain),
          ),
          const Center(child: Wordmark(size: 46)),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _comenzar,
                    style: FilledButton.styleFrom(
                      backgroundColor: R.verde,
                      foregroundColor: R.negro,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999)),
                    ),
                    child:
                        Text('COMENZAR', style: R.mono(size: 14, color: R.negro)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────── Shell con barra inferior

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final _feedKey = GlobalKey<_FeedTabState>();

  @override
  Widget build(BuildContext context) {
    final pages = [
      _FeedTab(key: _feedKey),
      const AmigosScreen(),
      const PerfilScreen(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_index]),
      floatingActionButton: _index == 0
          ? _CaptureButton(onTap: () => _feedKey.currentState?.capturar())
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: R.oliva,
          indicatorColor: R.verde,
          labelTextStyle: WidgetStateProperty.resolveWith((s) => R.mono(
              size: 10,
              color: s.contains(WidgetState.selected) ? R.papel : R.gris)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? R.negro : R.gris)),
        ),
        child: NavigationBar(
          height: 66,
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'FEED'),
            NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people_alt_rounded),
                label: 'AMIGOS'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'PERFIL'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Feed (tab)

class _FeedTab extends StatefulWidget {
  const _FeedTab({super.key});
  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> with WidgetsBindingObserver {
  late Future<List<Capture>> _future;
  List<RemoteCapture> _remote = [];
  Set<String> _amigos = {};
  Map<String, String> _avatarPorDispositivo = {}; // device_id → avatar_url
  String? _myDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = CaptureStore.all();
    _cargarTodo();
    _heartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _heartbeat();
      _cargarTodo();
    }
  }

  Future<void> _cargarTodo() async {
    _myDevice = await Backend.deviceId();
    final feed = await Backend.fetchFeed();
    final amigos = await Backend.amigos();
    final gente = await Backend.participantes();
    final avatares = <String, String>{};
    for (final p in gente) {
      final d = p['device_id'] as String?;
      final a = (p['avatar_url'] ?? p['rostro_url']) as String?;
      if (d != null && a != null) avatares[d] = a;
    }
    if (mounted) {
      setState(() {
        _remote = feed;
        _amigos = amigos;
        _avatarPorDispositivo = avatares;
      });
    }
  }

  Future<void> _heartbeat() async {
    final caps = await CaptureStore.all();
    final notif = await Notifications.permisoActivo();
    final loc = await locationOk();
    await Backend.heartbeat(
        notifOk: notif, locOk: loc, capturas: caps.length);
  }

  void _reload() {
    setState(() => _future = CaptureStore.all());
    _cargarTodo();
  }

  Future<void> capturar() async {
    final c = await captureMomento();
    if (!mounted) return;
    if (c != null) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: R.oliva,
        content: Text('¡momento publicado!',
            style: R.mono(size: 12, color: R.verde)),
      ));
      Backend.uploadCapture(c).then((_) {
        if (mounted) _cargarTodo();
      });
    }
  }

  void _toggleDev() {
    devMode.value = !devMode.value;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: R.oliva,
      content: Text(devMode.value ? 'MODO DEV ON' : 'MODO USUARIO',
          style: R.mono(size: 12, color: R.verde)),
      duration: const Duration(seconds: 1),
    ));
  }

  bool _postedToday(List<Capture> caps) {
    final now = DateTime.now();
    return caps.any((c) =>
        c.takenAt.year == now.year &&
        c.takenAt.month == now.month &&
        c.takenAt.day == now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeedTopBar(dev: devMode.value, onLongPress: _toggleDev, onDev: () {
          Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DevScreen()));
        }),
        Expanded(
          child: FutureBuilder<List<Capture>>(
            future: _future,
            builder: (context, snap) {
              final mine = snap.data ?? const <Capture>[];
              final posted = _postedToday(mine);
              return RefreshIndicator(
                color: R.verde,
                backgroundColor: R.oliva,
                onRefresh: () async => _reload(),
                child: _buildFeed(mine, posted),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeed(List<Capture> mine, bool posted) {
    final children = <Widget>[];

    if (!posted) {
      children.add(const _StatusBanner());
    }

    // Tu propio momento del día.
    if (mine.isNotEmpty) {
      children.add(_MyPost(capture: mine.first));
    }

    // Posts reales de otros (amigos primero; si no tienes, todos).
    final otros = _remote
        .where((r) => r.deviceId != _myDevice && r.backUrl.isNotEmpty)
        .toList();
    final deAmigos = otros.where((r) => _amigos.contains(r.deviceId)).toList();
    final visibles = deAmigos.isNotEmpty ? deAmigos : otros;

    if (otros.isEmpty) {
      children.add(const _EmptyHint(
          texto:
              'todavía nadie más ha publicado.\ncuando tus amigos capturen, aparecerán aquí.'));
    } else {
      if (deAmigos.isEmpty) {
        children.add(const _EmptyHint(
            texto:
                'aún no sigues a nadie.\nmira AMIGOS para agregar — mientras, esto es lo que hay.'));
      }
      for (final r in visibles) {
        children.add(_RemotePost(
          cap: r,
          locked: !posted,
          avatarUrl: _avatarPorDispositivo[r.deviceId],
          onTap: () {
            if (posted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RemotePostDetalle(
                    cap: r, avatarUrl: _avatarPorDispositivo[r.deviceId]),
              ));
            }
          },
        ));
      }
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (_, i) => children[i],
    );
  }
}

// ───────────────────────────────────────────────────────────── Componentes

class _FeedTopBar extends StatelessWidget {
  final bool dev;
  final VoidCallback onLongPress;
  final VoidCallback onDev;
  const _FeedTopBar(
      {required this.dev, required this.onLongPress, required this.onDev});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Expanded(
            child: Center(
              child: GestureDetector(
                onLongPress: onLongPress,
                child: const Wordmark(size: 24),
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: dev
                ? IconButton(
                    icon: const Icon(Icons.developer_mode, color: R.verde),
                    onPressed: onDev,
                  )
                : const SizedBox(),
          ),
        ],
      ),
    );
  }
}

/// Un solo aviso de estado (antes había tres compitiendo).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: R.oliva,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: R.verde, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Captura tu momento para ver el de los demás',
                style: R.display(size: 14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String texto;
  const _EmptyHint({required this.texto});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Text(texto,
              textAlign: TextAlign.center,
              style: R.display(size: 14, weight: FontWeight.w400, color: R.gris)),
        ),
      );
}

/// Tu propio post del día.
class _MyPost extends StatelessWidget {
  final Capture capture;
  const _MyPost({required this.capture});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _PostHeader(name: 'tú', when: 'ahora', isYou: true),
        Stack(
          children: [
            DualPhoto(
              big: File(capture.imagePath),
              small: capture.frontPath != null
                  ? File(capture.frontPath!)
                  : null,
            ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: MetaPill(icon: Icons.bolt, text: 'TU MOMENTO'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Post real de otro participante.
class _RemotePost extends StatelessWidget {
  final RemoteCapture cap;
  final bool locked;
  final String? avatarUrl;
  final VoidCallback onTap;
  const _RemotePost({
    required this.cap,
    required this.locked,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PostHeader(
                name: cap.alias,
                when: _relativo(cap.takenAt),
                avatarUrl: avatarUrl,
                alias: cap.alias),
            DualPhoto(
              bigUrl: cap.backUrl,
              smallUrl: cap.frontUrl,
              tone: cap.alias.length % 4,
              locked: locked,
            ),
            if (!locked) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.favorite_border, color: R.papel, size: 20),
                  const SizedBox(width: 16),
                  const Icon(Icons.mode_comment_outlined,
                      color: R.papel, size: 19),
                  const Spacer(),
                  Text('VER DETALLE', style: R.mono(size: 10, color: R.verde)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  final String name;
  final String when;
  final bool isYou;
  final String? avatarUrl;
  final String? alias; // si no es tuyo, para abrir su perfil
  const _PostHeader({
    required this.name,
    required this.when,
    this.isYou = false,
    this.avatarUrl,
    this.alias,
  });

  @override
  Widget build(BuildContext context) {
    void abrirPerfil() {
      if (alias != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => OtroPerfilScreen(alias: alias!)));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2, top: 2),
      child: Row(
        children: [
          GestureDetector(
            onTap: alias != null ? abrirPerfil : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: kTones[name.length % 4]),
                border: Border.all(color: isYou ? R.verde : R.gris, width: 1.2),
              ),
              child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? ClipOval(child: Image.network(avatarUrl!, fit: BoxFit.cover))
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: alias != null ? abrirPerfil : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: R.display(size: 16, weight: FontWeight.w700)),
                Text(when.toUpperCase(), style: R.mono(size: 11, color: R.gris)),
              ],
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: R.gris),
            onPressed: () => _postMenu(context, name),
          ),
        ],
      ),
    );
  }
}

/// Menú de un post.
void _postMenu(BuildContext context, String name) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: R.oliva,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: R.gris, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 10),
          for (final o in const [
            ('Compartir momento', Icons.ios_share),
            ('Guardar foto', Icons.bookmark_border),
            ('Ocultar este post', Icons.visibility_off_outlined),
            ('Reportar', Icons.flag_outlined),
          ])
            ListTile(
              leading: Icon(o.$2, color: R.papel),
              title:
                  Text(o.$1, style: R.display(size: 16, weight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: R.oliva,
                  duration: const Duration(milliseconds: 900),
                  content: Text(o.$1.toLowerCase(),
                      style: R.mono(size: 12, color: R.verde)),
                ));
              },
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

String _relativo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CaptureButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: R.negro,
          border: Border.all(color: R.papel, width: 4),
        ),
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: R.papel),
            child: const Icon(Icons.camera_alt_rounded, color: R.negro, size: 26),
          ),
        ),
      ),
    );
  }
}
