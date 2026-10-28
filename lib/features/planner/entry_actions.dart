import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/meal_picker.dart';

/// Charge utile d'un glisser-déposer depuis la bibliothèque (tablette).
class RecipeDrag {
  const RecipeDrag(this.recipeId);
  final String recipeId;
}

/// Charge utile d'un repas déjà planifié que l'on déplace.
class EntryDrag {
  const EntryDrag(this.entryId);
  final String entryId;
}

String slotArticle(SlotKind s) => switch (s) {
      SlotKind.breakfast => 'le petit-déj',
      SlotKind.lunch => 'le midi',
      SlotKind.snack => 'le goûter',
      SlotKind.dinner => 'le dîner',
    };

String slotSubtitle(DateTime d, SlotKind s, int guests) =>
    '${dayTitle(d)} · ${s.label} · ${pluralize(guests, 'personne')}';

/// Ouvre le sélecteur de repas puis écrit le choix dans le créneau.
Future<void> addMealToSlot(BuildContext context, WidgetRef ref, DateTime date, SlotKind slot) async {
  final store = ref.read(appStoreProvider.notifier);
  final guests = ref.read(currentGroupProvider).size;
  final pick = await showMealPicker(context, subtitle: slotSubtitle(date, slot, guests));
  if (pick == null) return;
  store.setMeal(date, slot, recipeId: pick.recipeId, freeText: pick.freeText);
}

/// Dépose [payload] (recette ou repas existant) sur un créneau.
void dropOnSlot(WidgetRef ref, Object payload, DateTime date, SlotKind slot) {
  final store = ref.read(appStoreProvider.notifier);
  switch (payload) {
    case RecipeDrag(:final recipeId):
      store.setMeal(date, slot, recipeId: recipeId);
    case EntryDrag(:final entryId):
      store.moveEntry(entryId, date, slot);
  }
}

/// Feuille d'actions sur un repas planifié : changer, convives, dupliquer, déplacer, supprimer.
Future<void> showEntryActions(BuildContext context, WidgetRef ref, PlanEntry entry) {
  final c = context.c;
  final store = ref.read(appStoreProvider.notifier);
  final recipes = ref.read(recipesByIdProvider);
  final title = recipes[entry.recipeId]?.title ?? entry.freeText ?? 'Repas';

  Future<DateTime?> pickDate(String help) => showDatePicker(
        context: context,
        initialDate: entry.date,
        firstDate: entry.date.subtract(const Duration(days: 60)),
        lastDate: entry.date.add(const Duration(days: 365)),
        helpText: help,
        locale: const Locale('fr'),
      );

  return showModalBottomSheet<void>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetCtx) {
      Widget action(IconData icon, String label, VoidCallback onTap, {Color? color}) => ListTile(
            leading: Icon(icon, color: color ?? c.onSurface),
            title: Text(label, style: TextStyle(fontWeight: FontWeight.w500, color: color ?? c.onSurface)),
            minVerticalPadding: 12,
            onTap: () {
              Navigator.pop(sheetCtx);
              onTap();
            },
          );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(title, style: c.heading(22)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Text(slotSubtitle(entry.date, entry.slot, entry.guests), style: TextStyle(color: c.muted)),
            ),
            action(Icons.swap_horiz, 'Changer de repas', () async {
              final pick = await showMealPicker(context, subtitle: slotSubtitle(entry.date, entry.slot, entry.guests));
              if (pick == null) return;
              store.setMeal(entry.date, entry.slot,
                  recipeId: pick.recipeId, freeText: pick.freeText, guests: entry.guests);
            }),
            action(Icons.people_outline, 'Convives : ${entry.guests}', () async {
              final n = await _askGuests(context, entry.guests);
              if (n != null) store.updateEntry(entry.copyWith(guests: n));
            }),
            action(Icons.content_copy, 'Dupliquer sur un autre jour', () async {
              final d = await pickDate('Dupliquer sur…');
              if (d != null) store.duplicateEntry(entry.id, d, entry.slot);
            }),
            action(Icons.drive_file_move_outline, 'Déplacer', () async {
              final d = await pickDate('Déplacer vers…');
              if (d != null) store.moveEntry(entry.id, d, entry.slot);
            }),
            action(Icons.delete_outline, 'Supprimer', () => store.removeEntry(entry.id), color: c.danger),
          ]),
        ),
      );
    },
  );
}

Future<int?> _askGuests(BuildContext context, int current) {
  var n = current;
  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Nombre de convives'),
        content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(
            onPressed: n > 1 ? () => setState(() => n--) : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Moins',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('$n', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          ),
          IconButton.filledTonal(
            onPressed: n < 40 ? () => setState(() => n++) : null,
            icon: const Icon(Icons.add),
            tooltip: 'Plus',
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, n), child: const Text('OK')),
        ],
      ),
    ),
  );
}

/// Sélecteur de groupe (F-GRP-04).
Future<void> showGroupSwitcher(BuildContext context, WidgetRef ref) {
  final c = context.c;
  final data = ref.read(appStoreProvider);
  return showModalBottomSheet<void>(
    context: context,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Mes groupes', style: c.heading(22)),
          ),
          for (final g in data.groups.where((g) => !g.archived))
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Color(g.color), borderRadius: BorderRadius.circular(12)),
                child: Text(g.initial,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF14161B))),
              ),
              title: Text(g.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(g.personal ? 'Espace personnel' : g.period.label),
              trailing: g.id == data.currentGroupId ? Icon(Icons.check, color: c.primary) : null,
              onTap: () {
                ref.read(appStoreProvider.notifier).selectGroup(g.id);
                Navigator.pop(sheetCtx);
              },
            ),
        ]),
      ),
    ),
  );
}
