import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                    Text('Popote', style: c.heading(40, letterSpacing: -0.8)),
                    const SizedBox(height: 12),
                    Text(
                      'Planifiez les repas à plusieurs, et la liste de courses se fait toute seule.',
                      style: TextStyle(fontSize: 17, height: 1.5, color: c.soft),
                    ),
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
                const SizedBox(height: 16),
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

/// Assiette illustrée (fourchette, couteau, trois aliments).
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: 300,
      height: 300,
      child: CustomPaint(painter: _PlatePainter(c)),
    );
  }
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.c);

  final MijoteColors c;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint();
    void dot(double x, double y, double r, Color color) => canvas.drawCircle(Offset(x, y), r, fill..color = color);
    final tone0 = c.tiles[0], tone1 = c.tiles[1], tone2 = c.tiles[2];
    dot(150, 150, 132, tone0.bg);
    dot(150, 150, 96, c.surface);
    canvas.drawCircle(
        const Offset(150, 150), 96, Paint()..color = c.outline..style = PaintingStyle.stroke..strokeWidth = 2);
    dot(150, 150, 70, tone2.bg);
    dot(128, 134, 20, tone0.fg);
    dot(172, 140, 16, tone1.fg);
    dot(150, 176, 18, tone2.fg);
    dot(58, 244, 10, tone1.fg);
    dot(248, 232, 7, tone0.fg);

    final line = Paint()
      ..color = c.onSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    // Fourchette
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
    // Couteau
    canvas.drawPath(
      Path()
        ..moveTo(262, 60)
        ..cubicTo(250, 60, 244, 74, 244, 92)
        ..cubicTo(244, 110, 250, 118, 262, 118)
        ..lineTo(262, 188),
      line,
    );
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.c != c;
}
