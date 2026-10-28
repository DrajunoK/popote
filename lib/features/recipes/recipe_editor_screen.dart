import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../domain/categorize.dart';
import '../../shared/widgets.dart';

const _units = ['', 'g', 'kg', 'ml', 'cl', 'l', 'pièce', 'c. à soupe', 'c. à café'];

class _IngRow {
  _IngRow({String name = '', String qty = '', this.unit = 'g', this.aisle = Aisle.grocery})
      : name = TextEditingController(text: name),
        qty = TextEditingController(text: qty);

  final TextEditingController name;
  final TextEditingController qty;
  String unit;
  Aisle aisle;

  void dispose() {
    name.dispose();
    qty.dispose();
  }
}

/// Création / modification d'une recette. Le mode « simple » (juste un nom) est mis en
/// avant pour ne pas bloquer la planification (F-REC-03).
class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _title = TextEditingController();
  final _steps = TextEditingController();
  final _prep = TextEditingController();
  final _cook = TextEditingController();
  final _ings = <_IngRow>[];

  late final String _id;
  bool _simple = true;
  int _servings = 4;
  Protein? _protein;
  Base? _base;
  DishType? _dish;
  Season _season = Season.all;
  bool _kids = false;
  bool _shared = true;
  bool _proteinTouched = false;
  bool _baseTouched = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.recipeId == null ? null : ref.read(recipesByIdProvider)[widget.recipeId];
    _id = existing?.id ?? ref.read(appStoreProvider.notifier).newId();
    if (existing != null) {
      _title.text = existing.title;
      _simple = existing.isSimple;
      _servings = existing.servings;
      _prep.text = existing.prepMin == 0 ? '' : '${existing.prepMin}';
      _cook.text = existing.cookMin == 0 ? '' : '${existing.cookMin}';
      _protein = existing.protein;
      _base = existing.base;
      _dish = existing.dish;
      _season = existing.season;
      _kids = existing.kidFriendly;
      _shared = existing.shared;
      _proteinTouched = _baseTouched = true;
      _steps.text = existing.steps.join('\n');
      for (final i in existing.ingredients) {
        _ings.add(_IngRow(
          name: i.name,
          qty: i.qty == 0 ? '' : _fmt(i.qty),
          unit: i.unit,
          aisle: i.aisle,
        ));
      }
    }
    if (_ings.isEmpty) _ings.add(_IngRow());
  }

  String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _title.dispose();
    _steps.dispose();
    _prep.dispose();
    _cook.dispose();
    for (final r in _ings) {
      r.dispose();
    }
    super.dispose();
  }

  /// Suggestion automatique tant que l'utilisateur n'a pas choisi lui-même (F-REC-10).
  void _suggest() {
    final names = _ings.map((r) => r.name.text.trim()).where((n) => n.isNotEmpty).toList();
    setState(() {
      if (!_proteinTouched) _protein = suggestProtein(names);
      if (!_baseTouched) _base = suggestBase(names);
    });
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Donnez un nom au repas.')));
      return;
    }
    final ingredients = _simple
        ? <RecipeIngredient>[]
        : [
            for (final r in _ings)
              if (r.name.text.trim().isNotEmpty)
                RecipeIngredient(
                  r.name.text.trim(),
                  double.tryParse(r.qty.text.replaceAll(',', '.')) ?? 0,
                  r.unit,
                  r.aisle,
                ),
          ];
    final recipe = Recipe(
      id: _id,
      title: title,
      servings: _servings,
      prepMin: int.tryParse(_prep.text) ?? 0,
      cookMin: int.tryParse(_cook.text) ?? 0,
      ingredients: ingredients,
      steps: _simple ? const [] : _steps.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      protein: _protein,
      base: _base,
      dish: _dish,
      season: _season,
      kidFriendly: _kids,
      shared: _shared,
    );
    ref.read(appStoreProvider.notifier).upsertRecipe(recipe);
    context.pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette recette ?'),
        content: const Text('Elle sera aussi retirée du planning.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    ref.read(appStoreProvider.notifier).deleteRecipe(_id);
    context.go('/recipes');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final editing = widget.recipeId != null;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(children: [
                  RoundIconButton(icon: Icons.close, label: 'Fermer', onTap: () => context.pop()),
                  const SizedBox(width: 10),
                  Expanded(child: Text(editing ? 'Modifier la recette' : 'Nouvelle recette', style: c.heading(24))),
                  if (editing) IconButton(tooltip: 'Supprimer', onPressed: _delete, icon: Icon(Icons.delete_outline, color: c.danger)),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                  _field(_title, 'Nom du repas', hint: 'Ex. Pizza maison', big: true),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _simple,
                      onChanged: (v) => setState(() => _simple = v),
                      title: const Text('Repas simple', style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Juste un nom, sans ingrédients : ne bloque pas la planification.', style: TextStyle(color: c.muted, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionLabel('Catégories'),
                  const _Hint('Utilisées par le bouton magique et les filtres.'),
                  _ChipGroup<Protein>(
                    title: 'Protéine principale',
                    values: Protein.values,
                    selected: _protein,
                    label: (p) => p.label,
                    onChanged: (p) => setState(() {
                      _protein = p;
                      _proteinTouched = true;
                    }),
                  ),
                  _ChipGroup<Base>(
                    title: 'Base',
                    values: Base.values,
                    selected: _base,
                    label: (b) => b.label,
                    onChanged: (b) => setState(() {
                      _base = b;
                      _baseTouched = true;
                    }),
                  ),
                  if (!_simple) ...[
                    _ChipGroup<DishType>(
                      title: 'Type de plat (facultatif)',
                      values: DishType.values,
                      selected: _dish,
                      label: (d) => d.label,
                      onChanged: (d) => setState(() => _dish = d),
                    ),
                    _ChipGroup<Season>(
                      title: 'Saison',
                      values: Season.values,
                      selected: _season,
                      label: (s) => s.label,
                      onChanged: (s) => setState(() => _season = s ?? Season.all),
                      allowClear: false,
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _kids,
                    onChanged: (v) => setState(() => _kids = v),
                    title: const Text('Apprécié des enfants'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _shared,
                    onChanged: (v) => setState(() => _shared = v),
                    title: const Text('Partagée avec le groupe'),
                    subtitle: Text(_shared ? 'Visible par les membres du groupe.' : 'Personnelle.', style: TextStyle(color: c.muted)),
                  ),
                  if (!_simple) ...[
                    const SizedBox(height: 8),
                    const SectionLabel('Temps & portions'),
                    Row(children: [
                      Expanded(child: _field(_prep, 'Préparation (min)', number: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_cook, 'Cuisson (min)', number: true)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('Portions', style: TextStyle(fontWeight: FontWeight.w600, color: c.soft)),
                      const Spacer(),
                      IconButton.filledTonal(onPressed: _servings > 1 ? () => setState(() => _servings--) : null, icon: const Icon(Icons.remove), tooltip: 'Moins'),
                      SizedBox(width: 48, child: Center(child: Text('$_servings', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
                      IconButton.filledTonal(onPressed: () => setState(() => _servings++), icon: const Icon(Icons.add), tooltip: 'Plus'),
                    ]),
                    const SizedBox(height: 16),
                    const SectionLabel('Ingrédients'),
                    for (final (i, row) in _ings.indexed) _ingredientRow(i, row),
                    const SizedBox(height: 4),
                    DashedBox(
                      radius: 14,
                      onTap: () => setState(() => _ings.add(_IngRow())),
                      child: SizedBox(
                        height: 48,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add, size: 18, color: c.primary),
                          const SizedBox(width: 8),
                          Text('Ajouter un ingrédient', style: TextStyle(fontWeight: FontWeight.w600, color: c.primary)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Étapes'),
                    const _Hint('Une étape par ligne.'),
                    TextField(
                      controller: _steps,
                      minLines: 4,
                      maxLines: 12,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _decoration('Faire revenir l’oignon…'),
                    ),
                  ],
                ]),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(color: c.background, border: Border(top: BorderSide(color: c.outline))),
                child: PillButton(label: 'Enregistrer', icon: Icons.check, onPressed: _save),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint, {String? label}) {
    final c = context.c;
    OutlineInputBorder border(Color color) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color));
    return InputDecoration(
      hintText: hint,
      labelText: label,
      filled: true,
      fillColor: c.surface,
      enabledBorder: border(c.outline),
      focusedBorder: border(c.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {String? hint, bool number = false, bool big = false}) => TextField(
        controller: ctrl,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
        style: TextStyle(fontSize: big ? 18 : 15, fontWeight: big ? FontWeight.w600 : FontWeight.w400),
        decoration: _decoration(hint ?? '', label: label),
      );

  Widget _ingredientRow(int i, _IngRow row) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: TextField(
            controller: row.name,
            onChanged: (_) => _suggest(),
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration('Ingrédient'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: row.qty,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _decoration('Qté'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: row.unit,
            isExpanded: true,
            decoration: _decoration(''),
            items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u.isEmpty ? 'au goût' : u, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => row.unit = v ?? ''),
          ),
        ),
        IconButton(
          tooltip: 'Rayon : ${row.aisle.label}',
          onPressed: () async {
            final a = await showModalBottomSheet<Aisle>(
              context: context,
              builder: (ctx) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
                  Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 8), child: Text('Rayon', style: c.heading(22))),
                  for (final a in Aisle.values)
                    ListTile(
                      title: Text(a.label),
                      trailing: a == row.aisle ? Icon(Icons.check, color: c.primary) : null,
                      onTap: () => Navigator.pop(ctx, a),
                    ),
                ]),
              ),
            );
            if (a != null) setState(() => row.aisle = a);
          },
          icon: Icon(Icons.storefront_outlined, color: c.muted),
        ),
        IconButton(
          tooltip: 'Retirer',
          onPressed: _ings.length > 1
              ? () => setState(() {
                    _ings.removeAt(i).dispose();
                    _suggest();
                  })
              : null,
          icon: Icon(Icons.close, color: c.muted),
        ),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: TextStyle(fontSize: 13, color: context.c.muted)));
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
    this.allowClear = true,
  });

  final String title;
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  final bool allowClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.c.soft)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final v in values)
              FilterPill(
                label: label(v),
                active: v == selected,
                height: 40,
                onTap: () => onChanged(v == selected && allowClear ? null : v),
              ),
          ]),
        ]),
      );
}
