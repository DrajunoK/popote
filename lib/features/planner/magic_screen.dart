import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../domain/magic_planner.dart';
import '../../shared/meal_picker.dart';
import '../../shared/widgets.dart';

/// Bouton magique : aperçu d'une semaine variée, ajustable avant validation (§3.8).
class MagicScreen extends ConsumerStatefulWidget {
  const MagicScreen({super.key});

  @override
  ConsumerState<MagicScreen> createState() => _MagicScreenState();
}

class _MagicScreenState extends ConsumerState<MagicScreen> {
  late PlannerRules _rules;
  late List<PlanSlot> _slots;
  final _locked = <int>{};

  /// Autres repas de la semaine (ex. les midis) : contraintes, jamais modifiés.
  final _others = <int, Recipe>{};

  /// Proposition courante par `PlanSlot.ord` (régénérée sauf lignes verrouillées).
  Map<int, Recipe> _proposal = {};
  List<String> _warnings = [];
  int _seed = DateTime.now().millisecondsSinceEpoch & 0xFFFFFF;

  @override
  void initState() {
    super.initState();
    final group = ref.read(currentGroupProvider);
    _rules = group.rules;
    final monday = ref.read(visibleWeekProvider);
    // Un seul repas par jour dans l'aperçu : le dîner (ou le dernier créneau du groupe).
    final first0 = monday;
    final kind = group.slots.contains(SlotKind.dinner) ? SlotKind.dinner : group.slots.last;
    _slots = [for (var i = 0; i < 7; i++) PlanSlot(monday.add(Duration(days: i)), kind)];
    final byId = ref.read(recipesByIdProvider);
    for (final e in ref.read(groupEntriesProvider)) {
      final r = byId[e.recipeId];
      final inWeek = !e.date.isBefore(first0) && !e.date.isAfter(first0.add(const Duration(days: 6)));
      if (r != null && inWeek && e.slot != kind) _others[PlanSlot(e.date, e.slot).ord] = r;
    }
    // Les repas déjà planifiés sont conservés (case cochée par défaut) et verrouillés.
    if (_rules.keepExisting) {
      final recipes = ref.read(recipesByIdProvider);
      for (final e in ref.read(groupEntriesProvider)) {
        final r = recipes[e.recipeId];
        final slot = _slots.where((s) => s.date == e.date && s.kind == e.slot).firstOrNull;
        if (r != null && slot != null) {
          _proposal[slot.ord] = r;
          _locked.add(slot.ord);
        }
      }
    }
    _compute();
  }

  Map<String, DateTime> get _history => ref.read(lastCookedProvider);

  void _run() => setState(_compute);

  /// Recalcule la proposition (sans `setState`, utilisable depuis `initState`).
  void _compute() {
    final recipes = ref.read(appStoreProvider).recipes;
    final fixedMap = {for (final k in _locked) if (_proposal[k] != null) k: _proposal[k]!};
    final toFill = _slots.where((s) => !_locked.contains(s.ord)).toList();
    final result = planMagic(
      slots: toFill,
      candidates: recipes,
      fixed: {..._others, ...fixedMap},
      lastCooked: _history,
      favorites: ref.read(appStoreProvider).favorites,
      rules: _rules,
      seed: _seed,
      today: dateOnly(DateTime.now()),
    );
    _proposal = {...fixedMap, ...result.picks};
    _warnings = result.warnings;
  }

  void _reroll() {
    _seed = math.Random().nextInt(1 << 24);
    _run();
  }

  Future<void> _replace(PlanSlot slot) async {
    final guests = ref.read(currentGroupProvider).size;
    final pick = await showMealPicker(context, subtitle: '${dayTitle(slot.date)} · ${slot.kind.label} · ${pluralize(guests, 'personne')}');
    final id = pick?.recipeId;
    if (id == null) return;
    final r = ref.read(recipesByIdProvider)[id];
    if (r == null) return;
    setState(() {
      _proposal = {..._proposal, slot.ord: r};
      _locked.add(slot.ord);
    });
  }

  void _validate() {
    final store = ref.read(appStoreProvider.notifier);
    final groupId = ref.read(appStoreProvider).currentGroupId;
    final existing = ref.read(groupEntriesProvider);
    final touched = <String>{};
    final added = <PlanEntry>[];
    for (final s in _slots) {
      final r = _proposal[s.ord];
      if (r == null) continue;
      final old = existing.where((e) => e.date == s.date && e.slot == s.kind).firstOrNull;
      if (old != null && old.recipeId == r.id) continue; // inchangé
      if (old != null) touched.add(old.id);
      added.add(store.newEntry(s.date, s.kind, r.id));
    }
    final removed = existing.where((e) => touched.contains(e.id)).toList();
    store.replaceEntries(removeIds: touched, add: added);
    store.updateRules(groupId, _rules);

    // Annulable pendant 10 s.
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        duration: const Duration(seconds: 10),
        content: Text('Semaine planifiée (${added.length} repas)'),
        action: SnackBarAction(
          label: 'Annuler',
          onPressed: () => store.replaceEntries(removeIds: added.map((e) => e.id).toSet(), add: removed),
        ),
      ));
    context.go('/planning');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final counts = <Protein, int>{};
    for (final r in _proposal.values) {
      final p = r.protein;
      if (p != null) counts[p] = (counts[p] ?? 0) + 1;
    }
    final group = ref.watch(currentGroupProvider);
    final first = _slots.first.date;
    final last = _slots.last.date;

    final ruleChips = <(String, bool, PlannerRules Function(PlannerRules))>[
      ('Varier les protéines', _rules.vary, (r) => r.copyWith(vary: !r.vary)),
      ('${_rules.minVeg} soirs végé min.', _rules.veg, (r) => r.copyWith(veg: !r.veg)),
      ('${_rules.minFish} soir poisson', _rules.fish, (r) => r.copyWith(fish: !r.fish)),
      ('Rapide en semaine', _rules.quick, (r) => r.copyWith(quick: !r.quick)),
      ('Saison', _rules.season, (r) => r.copyWith(season: !r.season)),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    RoundIconButton(icon: Icons.chevron_left, label: 'Retour au planning', onTap: () => context.pop()),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${group.name} · Dîners du ${dayMonth(first)} au ${dayMonth(last)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.muted)),
                        Row(children: [
                          Icon(Icons.auto_awesome, size: 22, color: c.tertiary),
                          const SizedBox(width: 8),
                          Flexible(child: Text('Ta semaine idéale', style: c.heading(24))),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (label, on, toggle) in ruleChips)
                      FilterPill(
                        label: label,
                        active: on,
                        height: 34,
                        onTap: () {
                          setState(() => _rules = toggle(_rules));
                          _run();
                        },
                      ),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.surface,
                      border: Border.all(color: c.outline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text('Équilibre', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
                      for (final p in Protein.values.where((p) => counts[p] != null))
                        Tag('${counts[p]} ${p.short}', bg: c.proteins[p]!.bg, fg: c.proteins[p]!.fg, vertical: 3),
                    ]),
                  ),
                  if (_warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final w in _warnings)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.info_outline, size: 16, color: c.tertiary),
                          const SizedBox(width: 6),
                          Expanded(child: Text(w, style: TextStyle(fontSize: 12, color: c.soft))),
                        ]),
                      ),
                  ],
                ]),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _slots.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final slot = _slots[i];
                    return _ProposalRow(
                      slot: slot,
                      recipe: _proposal[slot.ord],
                      locked: _locked.contains(slot.ord),
                      onTap: () => _replace(slot),
                      onToggleLock: () => setState(() {
                        if (!_locked.remove(slot.ord)) _locked.add(slot.ord);
                      }),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.outline))),
                child: Row(children: [
                  PillButton(label: 'Relancer', icon: Icons.refresh, primary: false, expand: false, onPressed: _reroll),
                  const SizedBox(width: 10),
                  Expanded(child: PillButton(label: 'Valider la semaine', icon: Icons.check, onPressed: _validate)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  const _ProposalRow({
    required this.slot,
    required this.recipe,
    required this.locked,
    required this.onTap,
    required this.onToggleLock,
  });

  final PlanSlot slot;
  final Recipe? recipe;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = recipe;
    final meta = r == null
        ? 'Aucune recette disponible'
        : '${r.base?.label ?? ''} · ${formatDuration(r.totalMin)}';
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: locked ? c.primary : c.outline, width: locked ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
          child: Row(children: [
            SizedBox(
              width: 48,
              child: Column(children: [
                Text(weekdayShort[slot.date.weekday - 1], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.muted)),
                Text('${slot.date.day}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r?.title ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Row(children: [
                  if (r?.protein != null) ...[ProteinBadge(r!.protein!), const SizedBox(width: 6)],
                  Flexible(child: Text(meta, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: c.muted))),
                ]),
              ]),
            ),
            Semantics(
              button: true,
              toggled: locked,
              label: locked ? 'Déverrouiller ${r?.title ?? ''}' : 'Verrouiller ${r?.title ?? ''}',
              child: Material(
                color: locked ? c.primary : c.surfaceVariant,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: r == null ? null : onToggleLock,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(locked ? Icons.lock : Icons.lock_open, size: 18, color: locked ? c.onPrimary : c.muted),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
