import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../domain/recipe_emoji.dart';

/// Visuel d'un repas : la photo de l'utilisateur si elle existe, sinon un emoji sur la teinte [tone].
class RecipeVisual extends StatelessWidget {
  const RecipeVisual({
    super.key,
    required this.recipe,
    required this.tone,
    this.size,
    this.height,
    this.radius = 12,
    this.emojiSize,
  });

  final Recipe recipe;
  final Tone tone;
  final double? size;

  /// Pour un visuel pleine largeur (carte, détail) : on fixe seulement la hauteur.
  final double? height;
  final double radius;
  final double? emojiSize;

  @override
  Widget build(BuildContext context) {
    final photo = recipe.photoPath;
    final side = size ?? height ?? 48;
    final Widget child = (photo != null && !kIsWeb)
        ? Image.file(
            File(photo),
            fit: BoxFit.cover,
            width: size,
            height: height ?? size,
            errorBuilder: (_, __, ___) => _emoji(side),
          )
        : _emoji(side);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: height ?? size, child: child),
    );
  }

  Widget _emoji(double side) => Container(
        color: tone.bg,
        alignment: Alignment.center,
        child: Text(recipeEmoji(recipe), style: TextStyle(fontSize: emojiSize ?? side * 0.5)),
      );
}
