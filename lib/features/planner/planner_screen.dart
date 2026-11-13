import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../shared/recipe_visual.dart';
import '../../shared/widgets.dart';
import 'entry_actions.dart';
import 'tablet_planner.dart';

/// Demande la période puis génère la liste de courses et ouvre l'onglet Courses.
///
/// Par défaut : de aujourd'hui (si la semaine affichée est la semaine en cours, les repas passés
/// sont déjà faits) ou du lundi, jusqu'au dimanche de la semaine affichée.
Future<void> generateShoppingList(BuildContext context, WidgetRef ref) async {
  final monday = ref.read(visibleWeekProvider);
  final sunday = monday.add(const Duration(days: 6));
  final today = dateOnly(DateTime.now());
  final current = !today.isBefore(monday) && !today.isAfter(sunday);
  final range = await showModalBottomSheet<DateTimeRange>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ShoppingPeriodSheet(start: current ? today : monday, weekEnd: sunday),
  );
  if (range == null || !context.mounted) return;
  ref.read(appStoreProvider.notifier).generateShopping(range.start, range.end);
  context.go('/shopping');
}

class _ShoppingPeriodSheet extends ConsumerStatefulWidget {
  const _ShoppingPeriodSheet({required this.start, required this.weekEnd});

  final DateTime start;
  final DateTime weekEnd;

  @override
  ConsumerState<_ShoppingPeriodSheet> createState() => _ShoppingPeriodSheetState();
}

class _ShoppingPeriodSheetState extends ConsumerState<_ShoppingPeriodSheet> {
  late DateTimeRange _range = DateTimeRange(start: widget.start, end: widget.weekEnd);

  DateTime get _twoWeeksEnd => widget.weekEnd.add(const Duration(days: 7));
  bool get _isOneWeek => _range.start == widget.start && _range.end == widget.weekEnd;
  bool get _isTwoWeeks => _range.start == widget.start && _range.end == _twoWeeksEnd;

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: widget.start.subtract(const Duration(days: 60)),
      lastDate: widget.start.add(const Duration(days: 365)),
      helpText: 'Période des courses',
      locale: const Locale('fr'),
    );
    if (picked != null) setState(() => _range = DateTimeRange(start: dateOnly(picked.start), end: dateOnly(picked.end)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final recipes = ref.watch(recipesByIdProvider);
    final meals = ref.watch(groupEntriesProvider).where((e) {
      final r = recipes[e.recipeId];
      return r != null && !r.isSimple && !e.date.isBefore(_range.start) && !e.date.isAfter(_range.end);
    }).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Courses pour…', style: c.heading(22)),
          const SizedBox(height: 4),
          Text('Du ${dayMonth(_range.start)} au ${dayMonth(_range.end)} · ${pluralize(meals, 'repas', 'repas')}',
              style: TextStyle(color: c.muted)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilterPill(
              label: 'Cette semaine',
              active: _isOneWeek,
              onTap: () => setState(() => _range = DateTimeRange(start: widget.start, end: widget.weekEnd)),
            ),
            FilterPill(
              label: '2 semaines',
              active: _isTwoWeeks,
              onTap: () => setState(() => _range = DateTimeRange(start: widget.start, end: _twoWeeksEnd)),
            ),
            FilterPill(label: 'Choisir les dates', active: !_isOneWeek && !_isTwoWeeks, onTap: _pickDates),
          ]),
          const SizedBox(height: 10),
          Text('La liste actuelle est remplacée ; les produits frais des repas lointains sont signalés.',
              style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 16),
          PillButton(
            label: meals == 0 ? 'Aucun repas avec ingrédients' : 'Générer la liste',
            icon: Icons.shopping_cart_outlined,
            onPressed: meals == 0 ? null : () => Navigator.pop(context, _range),
          ),
        ]),
      ),
    );
  }
}

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    // Tablette paysage : planning + bibliothèque côte à côte (spec §6.3).
    // La rail de navigation occupe 88 dp : on compare à la largeur utile. Il faut ~1100 dp pour
    // 7 colonnes lisibles + la bibliothèque de 340 dp ; en dessous, la vue téléphone (centrée).
    if (width - 88 >= 1100) return const TabletPlanner();
    return const _PhonePlanner();
  }
}

class _PhonePlanner extends ConsumerStatefulWidget {
  const _PhonePlanner();

  @override
  ConsumerState<_PhonePlanner> createState() => _PhonePlannerState();
}

class _PhonePlannerState extends ConsumerState<_PhonePlanner> {
  final _keys = List.generate(7, (_) => GlobalKey());
  int _selected = -1;

  int _initialSelection(DateTime monday) {
    final today = dateOnly(DateTime.now());
    final i = today.difference(monday).inDays;
    return i >= 0 && i < 7 ? i : 0;
  }

  void _select(int i) {
    setState(() => _selected = i);
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final monday = ref.watch(visibleWeekProvider);
    final group = ref.watch(currentGroupProvider);
    final entries = ref.watch(groupEntriesProvider);
    final recipes = ref.watch(recipesByIdProvider);
    final user = ref.watch(appStoreProvider.select((d) => d.user));
    final today = dateOnly(DateTime.now());
    final selected = _selected >= 0 ? _selected : _initialSelection(monday);

    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    PlanEntry? entryAt(DateTime d, SlotKind s) =>
        entries.where((e) => e.date == d && e.slot == s).firstOrNull;
    final weekEmpty = !days.any((d) => entries.any((e) => e.date == d));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _GroupChip(group: group, onTap: () => showGroupSwitcher(context, ref)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Vue du mois',
                    onPressed: () => context.push('/month'),
                    icon: Icon(Icons.calendar_view_month_outlined, color: c.muted),
                  ),
                  const SizedBox(width: 4),
                Semantics(
                  label: 'Mon profil',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.push('/profile'),
                    child: _AvatarStack(group: group, me: user?.initial ?? 'A'),
                  ),
                ),
                ]),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                IconButton(
                  tooltip: 'Semaine précédente',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(visibleWeekProvider.notifier).shift(-1),
                  icon: Icon(Icons.chevron_left, color: c.muted),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      ref.read(visibleWeekProvider.notifier).reset();
                      setState(() => _selected = -1);
                    },
                    child: Text(weekLabel(monday),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.muted)),
                  ),
                ),
                IconButton(
                  tooltip: 'Semaine suivante',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => ref.read(visibleWeekProvider.notifier).shift(1),
                  icon: Icon(Icons.chevron_right, color: c.muted),
                ),
              ]),
              Text('On mange quoi ?', style: c.heading(30, letterSpacing: -0.3)),
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                      child: _DayButton(
                        date: days[i],
                        active: i == selected,
                        hasMeals: entries.any((e) => e.date == days[i]),
                        onTap: () => _select(i),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(children: [
                if (weekEmpty) ...[
                  _EmptyWeek(onMagic: () => context.push('/magic')),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < 7; i++) ...[
                  KeyedSubtree(
                    key: _keys[i],
                    child: _DayCard(
                      date: days[i],
                      isToday: days[i] == today,
                      slots: group.slots,
                      entryAt: (s) => entryAt(days[i], s),
                      recipes: recipes,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.outline))),
            child: Row(children: [
              PillButton(
                label: 'Magique',
                icon: Icons.auto_awesome,
                primary: false,
                expand: false,
                height: 48,
                onPressed: () => context.push('/magic'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton(
                  label: 'Générer les courses',
                  icon: Icons.shopping_cart_outlined,
                  height: 48,
                  onPressed: () => generateShoppingList(context, ref),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({required this.group, required this.onTap});

  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      shape: StadiumBorder(side: BorderSide(color: c.outline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            InitialAvatar(group.initial, bg: Color(group.color), fg: const Color(0xFF14161B), size: 32),
            const SizedBox(width: 8),
            Text(group.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.expand_more, size: 18, color: c.onSurface),
          ]),
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.group, required this.me});

  final Group group;
  final String me;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final names = group.members.map((m) => m.isMe ? me : m.name.substring(0, 1).toUpperCase()).toList();
    final shown = names.take(2).toList();
    final extra = names.length - shown.length;
    final tones = [c.tiles[2], c.tiles[1], c.tiles[0]];
    return SizedBox(
      height: 44,
      child: Row(children: [
        for (var i = 0; i < shown.length; i++)
          Transform.translate(
            offset: Offset(-10.0 * i, 0),
            child: InitialAvatar(shown[i], bg: tones[i % 3].bg, fg: c.onSurface, size: 32, border: c.background),
          ),
        if (extra > 0)
          Transform.translate(
            offset: Offset(-10.0 * shown.length, 0),
            child: InitialAvatar('+$extra', bg: tones[2].bg, fg: c.onSurface, size: 32, border: c.background),
          ),
      ]),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({required this.date, required this.active, required this.hasMeals, required this.onTap});

  final DateTime date;
  final bool active;
  final bool hasMeals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isToday = date == dateOnly(DateTime.now());
    return Semantics(
      button: true,
      selected: active,
      label: dayTitle(date),
      child: Material(
        color: active ? c.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(weekdayShort[date.weekday - 1],
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? c.onPrimary : c.muted)),
              const SizedBox(height: 2),
              Text('${date.day}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: active ? c.onPrimary : (isToday ? c.primary : c.onSurface),
                  )),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? c.surface : (hasMeals ? c.secondary : c.outline),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyWeek extends ConsumerWidget {
  const _EmptyWeek({required this.onMagic});

  final VoidCallback onMagic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.auto_awesome, color: c.tertiary),
        const SizedBox(width: 12),
        Expanded(
          child: Text('Aucun repas cette semaine. Ajoutez-en un ci-dessous, ou laissez la magie faire.',
              style: TextStyle(color: c.soft, height: 1.35)),
        ),
        TextButton(onPressed: onMagic, child: const Text('Remplir')),
      ]),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({
    required this.date,
    required this.isToday,
    required this.slots,
    required this.entryAt,
    required this.recipes,
  });

  final DateTime date;
  final bool isToday;
  final List<SlotKind> slots;
  final PlanEntry? Function(SlotKind) entryAt;
  final Map<String, Recipe> recipes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(dayTitle(date), style: c.heading(18)),
          if (isToday) Tag('Aujourd’hui', bg: c.primaryContainer, fg: c.onPrimaryContainer),
        ]),
        for (var i = 0; i < slots.length; i++) ...[
          Builder(builder: (_) {
            final slot = slots[i];
            final e = entryAt(slot);
            final isLast = i == slots.length - 1;
            if (e == null) {
              return Padding(
                padding: EdgeInsets.only(top: 8, bottom: isLast ? 10 : 2),
                child: DashedBox(
                  onTap: () => addMealToSlot(context, ref, date, slot),
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.centerLeft,
                    child: Row(children: [
                      Icon(Icons.add, size: 20, color: c.primary),
                      const SizedBox(width: 12),
                      Text('Ajouter ${slotArticle(slot)}',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.primary)),
                    ]),
                  ),
                ),
              );
            }
            return _SlotRow(entry: e, recipe: recipes[e.recipeId], showDivider: !isLast);
          }),
        ],
      ]),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.entry, required this.recipe, required this.showDivider});

  final PlanEntry entry;
  final Recipe? recipe;
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tone = c.slotTone(entry.slot);
    final isNote = recipe == null;
    final title = recipe?.title ?? entry.freeText ?? 'Repas';
    final trailing = isNote || (recipe?.totalMin ?? 0) == 0 ? 'Note' : formatDuration(recipe!.totalMin);
    return Semantics(
      button: true,
      label: '${entry.slot.label} : $title. Appui pour modifier.',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showEntryActions(context, ref, entry),
        onLongPress: () => showEntryActions(context, ref, entry),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: showDivider ? Border(bottom: BorderSide(color: c.surfaceVariant)) : null,
          ),
          child: Row(children: [
            if (recipe case final r?)
              RecipeVisual(recipe: r, tone: tone, size: 48)
            else
              MealTile(tone: Tone(c.surfaceVariant, c.muted), icon: Icons.inventory_2_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.slot.label.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.66, color: c.slotColor(entry.slot))),
                const SizedBox(height: 2),
                Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ]),
            ),
            Text(trailing, style: TextStyle(fontSize: 13, color: c.muted)),
          ]),
        ),
      ),
    );
  }
}
