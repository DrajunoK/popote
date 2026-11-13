import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

final _monthTitle = DateFormat('MMMM yyyy', 'fr');

/// Vue mensuelle façon agenda : chaque jour montre ses repas planifiés (pastille pleine)
/// et ceux qui manquent encore (pastille vide). Un appui ouvre la semaine du jour.
class MonthScreen extends ConsumerStatefulWidget {
  const MonthScreen({super.key});

  @override
  ConsumerState<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends ConsumerState<MonthScreen> {
  late DateTime _month = () {
    final monday = ref.read(visibleWeekProvider);
    // Le mois de la semaine affichée (le jeudi tranche, comme pour les semaines ISO).
    final thursday = monday.add(const Duration(days: 3));
    return DateTime(thursday.year, thursday.month);
  }();

  void _shift(int months) => setState(() => _month = DateTime(_month.year, _month.month + months));

  void _open(DateTime day) {
    ref.read(visibleWeekProvider.notifier).goTo(day);
    context.go('/planning');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final group = ref.watch(currentGroupProvider);
    final entries = ref.watch(groupEntriesProvider);
    final recipes = ref.watch(recipesByIdProvider);
    final today = dateOnly(DateTime.now());

    final first = _month;
    final gridStart = mondayOf(first);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final weeks = ((first.weekday - 1 + daysInMonth) / 7).ceil();
    final slots = group.slots;

    // Un index par jour évite de refiltrer toute la liste pour chaque case.
    final byDay = <DateTime, Map<SlotKind, PlanEntry>>{};
    for (final e in entries) {
      byDay.putIfAbsent(e.date, () => {})[e.slot] = e;
    }

    var planned = 0, missing = 0;
    for (var d = 0; d < daysInMonth; d++) {
      final date = DateTime(first.year, first.month, d + 1);
      final day = byDay[date] ?? const {};
      for (final s in slots) {
        if (day.containsKey(s)) {
          planned++;
        } else if (!date.isBefore(today)) {
          missing++;
        }
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(children: [
                Row(children: [
                  RoundIconButton(icon: Icons.chevron_left, label: 'Retour au planning', onTap: () => context.pop()),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Mois précédent',
                    onPressed: () => _shift(-1),
                    icon: Icon(Icons.chevron_left, color: c.muted),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _month = DateTime(today.year, today.month)),
                      child: Text(capitalize(_monthTitle.format(first)),
                          textAlign: TextAlign.center, style: c.heading(22)),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Mois suivant',
                    onPressed: () => _shift(1),
                    icon: Icon(Icons.chevron_right, color: c.muted),
                  ),
                  const SizedBox(width: 48),
                ]),
                const SizedBox(height: 4),
                Text(
                  '$planned planifié${planned > 1 ? 's' : ''} · $missing à planifier',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  for (final d in weekdayShort)
                    Expanded(
                      child: Center(
                        child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.muted)),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Expanded(
                  child: Column(children: [
                    for (var w = 0; w < weeks; w++)
                      Expanded(
                        child: Row(children: [
                          for (var i = 0; i < 7; i++)
                            Expanded(
                              child: Builder(builder: (_) {
                                final date = gridStart.add(Duration(days: w * 7 + i));
                                return _DayCell(
                                  date: date,
                                  inMonth: date.month == first.month,
                                  isToday: date == today,
                                  isPast: date.isBefore(today),
                                  slots: slots,
                                  entries: byDay[date] ?? const {},
                                  recipes: recipes,
                                  onTap: () => _open(date),
                                );
                              }),
                            ),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  for (final s in slots) _Legend(color: c.slotColor(s), label: s.label),
                  _Legend(color: c.outline, label: 'À planifier', hollow: true),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.hollow = false});

  final Color color;
  final String label;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: hollow ? null : color,
          border: hollow ? Border.all(color: color, width: 1.5) : null,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.isPast,
    required this.slots,
    required this.entries,
    required this.recipes,
    required this.onTap,
  });

  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final bool isPast;
  final List<SlotKind> slots;
  final Map<SlotKind, PlanEntry> entries;
  final Map<String, Recipe> recipes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final summary = [
      for (final s in slots)
        '${s.label} : ${entries[s] == null ? 'rien de prévu' : _title(entries[s]!)}',
    ].join(', ');
    return Semantics(
      button: true,
      label: '${dayTitle(date)}. $summary',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: inMonth ? c.surface : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isToday ? c.primary : (inMonth ? c.outline : Colors.transparent), width: isToday ? 1.5 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Opacity(
              opacity: inMonth ? 1 : 0.35,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: isToday ? BoxDecoration(color: c.primary, shape: BoxShape.circle) : null,
                      child: Text('${date.day}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isToday ? c.onPrimary : (isPast ? c.muted : c.onSurface))),
                    ),
                  ),
                  const SizedBox(height: 2),
                  for (final s in slots)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: _SlotChip(slot: s, entry: entries[s], recipes: recipes, dim: isPast),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _title(PlanEntry e) => recipes[e.recipeId]?.title ?? e.freeText ?? 'Repas';
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.entry, required this.recipes, required this.dim});

  final SlotKind slot;
  final PlanEntry? entry;
  final Map<String, Recipe> recipes;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final e = entry;
    if (e == null) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: dim ? c.outline : c.slotColor(slot).withValues(alpha: 0.6), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    final tone = c.slotTone(slot);
    final title = recipes[e.recipeId]?.title ?? e.freeText ?? 'Repas';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(4)),
      child: Text(title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 9, height: 1.1, fontWeight: FontWeight.w600, color: tone.fg)),
    );
  }
}
