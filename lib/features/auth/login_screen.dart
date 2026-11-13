import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pwa_install.dart';
import '../../core/theme.dart';
import '../../data/auth_service.dart';
import '../groups/join_group.dart';

/// Connexion Google (F-AUTH-01).
///
/// Passe par Supabase Auth quand `SUPABASE_URL` et `SUPABASE_ANON_KEY` sont fournis,
/// sinon crée un profil local de démonstration.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    void signIn() => ref.read(authServiceProvider).signInWithGoogle();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: Column(children: [
                const Expanded(child: Center(child: _Illustration())),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const _PrivateBadge(),
                    const SizedBox(height: 14),
                    Text('Popote', style: c.heading(40, letterSpacing: -0.8)),
                    const SizedBox(height: 12),
                    Text(
                      'Planifiez les repas à plusieurs, et la liste de courses se fait toute seule.',
                      style: TextStyle(fontSize: 17, height: 1.5, color: c.soft),
                    ),
                    const SizedBox(height: 10),
                    const _RotatingTagline(),
                  ]),
                ),
                const SizedBox(height: 32),
                _AuthButton(
                  height: 56,
                  background: c.inverse,
                  foreground: c.onInverse,
                  onTap: signIn,
                  leading: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                    child: Text('G', style: TextStyle(fontWeight: FontWeight.w700, color: c.onSurface)),
                  ),
                  label: 'Continuer avec Google',
                ),
                const SizedBox(height: 12),
                _AuthButton(
                  height: 52,
                  background: c.surface,
                  foreground: c.onSurface,
                  border: c.outlineStrong,
                  onTap: () => _join(context, ref),
                  leading: Icon(Icons.link, size: 20, color: c.onSurface),
                  label: 'J’ai un code d’invitation',
                ),
                const _InstallButton(),
                const SizedBox(height: 16),
                Text(
                  'Espace privé : connectez-vous pour entrer, ou rejoignez un groupe avec un code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.5, color: c.soft),
                ),
                const SizedBox(height: 6),
                Text(
                  'En continuant, vous acceptez les conditions et la politique de confidentialité.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.5, color: c.muted),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Le code est gardé, puis utilisé juste après la connexion Google.
  Future<void> _join(BuildContext context, WidgetRef ref) async {
    if (await askAndJoinGroup(context, ref)) {
      await ref.read(authServiceProvider).signInWithGoogle();
    }
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.height,
    required this.background,
    required this.foreground,
    required this.onTap,
    required this.leading,
    required this.label,
    this.border,
  });

  final double height;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onTap;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) => Material(
        color: background,
        shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border!)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              leading,
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: foreground)),
            ]),
          ),
        ),
      );
}

/// « Installer l'appli » : visible seulement sur le web, tant que Popote n'est pas installée.
class _InstallButton extends StatelessWidget {
  const _InstallButton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ValueListenableBuilder<PwaInstallState>(
      valueListenable: pwaInstall,
      builder: (context, state, _) {
        if (state == PwaInstallState.none) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: _AuthButton(
            height: 52,
            background: c.tiles[1].bg,
            foreground: c.tiles[1].fg,
            onTap: () => state == PwaInstallState.available ? promptPwaInstall() : _showIosHelp(context),
            leading: Icon(Icons.install_mobile, size: 20, color: c.tiles[1].fg),
            label: 'Installer l’appli',
          ),
        );
      },
    );
  }

  void _showIosHelp(BuildContext context) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Installer Popote'),
          content: const Text(
            'Dans Safari : touchez Partager (le carré avec une flèche), '
            'puis « Sur l’écran d’accueil ».',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
}

/// Pastille « espace privé ».
class _PrivateBadge extends StatelessWidget {
  const _PrivateBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.tiles[0].bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_outline, size: 14, color: c.tiles[0].fg),
        const SizedBox(width: 6),
        Text('Espace privé · sur invitation',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.tiles[0].fg)),
      ]),
    );
  }
}

/// Phrase d'accroche qui change toutes les 3 s (figée si les animations sont réduites).
class _RotatingTagline extends StatefulWidget {
  const _RotatingTagline();

  @override
  State<_RotatingTagline> createState() => _RotatingTaglineState();
}

class _RotatingTaglineState extends State<_RotatingTagline> {
  static const _lines = [
    'Ce soir, on mange quoi ? 🍝',
    'Fini les « j’sais pas, et toi ? »',
    'Le frigo vide, c’est la fin des haricots 🫘',
    'Zéro prise de tête, 100 % popote',
    'Qui fait les courses ? Pas vous, la liste ! 🛒',
  ];
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || MediaQuery.of(context).disableAnimations) return;
      setState(() => _i = (_i + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 24,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim),
            child: child,
          ),
        ),
        child: Align(
          key: ValueKey(_i),
          alignment: Alignment.centerLeft,
          child: Text(_lines[_i],
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.tiles[1].fg)),
        ),
      ),
    );
  }
}

/// Assiette illustrée et animée : elle flotte, la vapeur monte, les aliments sautillent.
class _Illustration extends StatefulWidget {
  const _Illustration();

  @override
  State<_Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<_Illustration> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 300,
      height: 300,
      child: CustomPaint(painter: _PlatePainter(c, _ctrl)),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.c, this.anim) : super(repaint: anim);

  final MijoteColors c;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * 2 * math.pi; // un tour complet = 6 s
    final fill = Paint();
    void dot(double x, double y, double r, Color color) => canvas.drawCircle(Offset(x, y), r, fill..color = color);
    final tone0 = c.tiles[0], tone1 = c.tiles[1], tone2 = c.tiles[2];

    // L'ensemble flotte doucement.
    canvas.save();
    canvas.translate(0, math.sin(t) * 5);

    dot(150, 150, 132, tone0.bg);
    dot(150, 150, 96, c.surface);
    canvas.drawCircle(
        const Offset(150, 150), 96, Paint()..color = c.outline..style = PaintingStyle.stroke..strokeWidth = 2);
    dot(150, 150, 70, tone2.bg);

    // Aliments qui sautillent, déphasés.
    dot(128, 134 + math.sin(t * 2) * 4, 20, tone0.fg);
    dot(172, 140 + math.sin(t * 2 + 2.1) * 4, 16, tone1.fg);
    dot(150, 176 + math.sin(t * 2 + 4.2) * 4, 18, tone2.fg);

    // Petites billes qui tournent autour de l'assiette.
    dot(58 + math.cos(t) * 6, 244 + math.sin(t) * 6, 10, tone1.fg);
    dot(248 + math.cos(t + 2) * 5, 232 + math.sin(t + 2) * 5, 7, tone0.fg);

    // Vapeur : trois volutes qui montent en s'effaçant.
    for (var k = 0; k < 3; k++) {
      final phase = (anim.value + k / 3) % 1.0;
      final x = 120.0 + k * 30 + math.sin(phase * 2 * math.pi * 2 + k) * 6;
      final y = 66 - phase * 46;
      final steam = Paint()
        ..color = c.onSurface.withValues(alpha: (1 - phase) * 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(
        Path()
          ..moveTo(x, y + 22)
          ..quadraticBezierTo(x + 8, y + 11, x, y)
          ..quadraticBezierTo(x - 8, y - 11, x, y - 22),
        steam,
      );
    }
    canvas.restore();

    final line = Paint()
      ..color = c.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    // Fourchette (balance légèrement)
    canvas.save();
    canvas.translate(40, 120);
    canvas.rotate(math.sin(t) * 0.05);
    canvas.translate(-40, -120);
    canvas.drawPath(
      Path()
        ..moveTo(40, 60)
        ..lineTo(40, 120)
        ..moveTo(30, 60)
        ..lineTo(30, 86)
        ..arcToPoint(const Offset(50, 86), radius: const Radius.circular(10), clockwise: false)
        ..lineTo(50, 60),
      line,
    );
    canvas.restore();
    // Couteau (balance en sens inverse)
    canvas.save();
    canvas.translate(262, 120);
    canvas.rotate(-math.sin(t) * 0.05);
    canvas.translate(-262, -120);
    canvas.drawPath(
      Path()
        ..moveTo(262, 60)
        ..cubicTo(250, 60, 244, 74, 244, 92)
        ..cubicTo(244, 110, 250, 118, 262, 118)
        ..lineTo(262, 188),
      line,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.c != c;
}
