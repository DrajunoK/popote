import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

/// Bordure en pointillés arrondie (créneau vide, « + Créer »).
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.color,
    this.fill,
    this.radius = 14,
    this.strokeWidth = 1.5,
    this.onTap,
  });

  final Widget child;
  final Color? color;
  final Color? fill;
  final double radius;
  final double strokeWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return CustomPaint(
      painter: _DashPainter(color ?? c.outlineStrong, fill, radius, strokeWidth),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: child),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter(this.color, this.fill, this.radius, this.stroke);

  final Color color;
  final Color? fill;
  final double radius;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke),
      Radius.circular(radius),
    );
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final path = Path()..addRRect(rrect);
    for (final PathMetric m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.fill != fill || old.radius != radius || old.stroke != stroke;
}

/// Petit titre de section en capitales (« RAYON », « MEMBRES · 4 »).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.bottom = 8});

  final String text;
  final double bottom;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.72, color: context.c.muted),
        ),
      );
}

/// Étiquette arrondie (rôle, « Aujourd'hui », compteur d'équilibre…).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, required this.bg, required this.fg, this.fontSize = 12, this.vertical = 4});

  final String text;
  final Color bg;
  final Color fg;
  final double fontSize;
  final double vertical;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: vertical),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg)),
      );
}

/// Badge de protéine (vert = végé, bleu = poisson, moutarde = volaille, terracotta = bœuf, rose = porc).
class ProteinBadge extends StatelessWidget {
  const ProteinBadge(this.protein, {super.key});

  final Protein protein;

  @override
  Widget build(BuildContext context) {
    final t = context.c.proteins[protein]!;
    return Tag(protein.short, bg: t.bg, fg: t.fg, fontSize: 11, vertical: 2);
  }
}

/// Chip de filtre (plein quand actif).
class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.active, required this.onTap, this.height = 36});

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? c.inverse : c.surface,
        shape: StadiumBorder(side: BorderSide(color: active ? c.inverse : c.outline)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? c.onInverse : c.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton principal arrondi (« Générer les courses », « Valider »).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.height = 52,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fg = primary ? c.onPrimary : c.onSurface;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
        ),
      ],
    );
    return Material(
      color: primary ? c.primary : c.surface,
      shape: StadiumBorder(side: primary ? BorderSide.none : BorderSide(color: c.outlineStrong)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// Bouton rond avec icône (retour, partage, réglages) — cible ≥ 44 dp.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: c.surface,
        shape: CircleBorder(side: BorderSide(color: c.outline)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 20, color: c.onSurface)),
        ),
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({super.key, required this.hint, required this.onChanged, this.height = 48, this.filled});

  final String hint;
  final ValueChanged<String> onChanged;
  final double height;
  final Color? filled;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: filled ?? c.surface,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(Icons.search, size: 20, color: c.muted),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: c.muted),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ]),
    );
  }
}

/// Vignette de recette (pas de photo en v1 : teinte du thème + icône couverts).
class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.tone, this.size = 48, this.icon = Icons.restaurant, this.radius = 12});

  final Tone tone;
  final double size;
  final IconData? icon;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(radius)),
        child: icon == null ? null : Icon(icon, size: size * 0.46, color: tone.fg),
      );
}

/// Pastille ronde avec une initiale.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.text, {super.key, required this.bg, required this.fg, this.size = 40, this.border});

  final String text;
  final Color bg;
  final Color fg;
  final double size;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border!, width: 2),
        ),
        child: Text(text, style: TextStyle(fontWeight: FontWeight.w600, fontSize: size * 0.4, color: fg)),
      );
}

/// Carte standard : surface + bordure + rayon 20.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 6), this.radius = 20});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.outline),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }
}

/// Barre de recherche + onglets segmentés réutilisés par le sélecteur de repas.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == index,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: i == index
                        ? [BoxShadow(color: Colors.black.withAlpha(c.isDark ? 100 : 30), blurRadius: 3, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: i == index ? c.onSurface : c.muted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Saisie d'une ligne de texte dans une boîte de dialogue.
Future<String?> askText(BuildContext context, {required String title, String? hint, String? initial}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('OK')),
      ],
    ),
  );
}
