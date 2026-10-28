import 'package:intl/intl.dart';

import '../data/models.dart';

final _day = DateFormat('EEEE d', 'fr');
final _dayMonth = DateFormat('d MMM', 'fr');

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// « Mardi 27 »
String dayTitle(DateTime d) => capitalize(_day.format(d));

/// « 26 oct »
String dayMonth(DateTime d) => _dayMonth.format(d).replaceAll('.', '');

const weekdayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

DateTime mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Numéro de semaine ISO 8601.
int isoWeek(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final firstThursday = DateTime.utc(thursday.year, 1, 4);
  final week1Thursday = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
  return 1 + thursday.difference(week1Thursday).inDays ~/ 7;
}

/// « Semaine 44 · 26 oct – 1 nov »
String weekLabel(DateTime monday) =>
    'Semaine ${isoWeek(monday)} · ${dayMonth(monday)} – ${dayMonth(monday.add(const Duration(days: 6)))}';

/// 75 → « 1 h 15 », 45 → « 45 min », 60 → « 1 h ».
String formatDuration(int minutes) {
  if (minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
}

String _num(double v) {
  final r = (v * 100).round() / 100;
  final s = r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toString();
  return s.replaceAll('.', ',');
}

/// Affiche une quantité de courses : « 400 g », « 1,2 kg », « 40 cl », « 6 ».
String formatQty(double qty, String unit) {
  if (qty <= 0) return '';
  switch (unit) {
    case 'g':
      return qty >= 1000 ? '${_num(qty / 1000)} kg' : '${_num(qty)} g';
    case 'ml':
      if (qty >= 1000) return '${_num(qty / 1000)} l';
      if (qty >= 100 && qty % 10 == 0) return '${_num(qty / 10)} cl';
      return '${_num(qty)} ml';
    case 'pièce':
    case '':
      return _num(qty);
    default:
      return '${_num(qty)} $unit';
  }
}

String pluralize(int n, String singular, [String? plural]) =>
    '$n ${n > 1 ? (plural ?? '${singular}s') : singular}';

/// « jamais cuisiné », « cette semaine », « il y a 10 j », « il y a 3 sem. », « il y a 2 mois ».
String agoLabel(DateTime? last, DateTime today) {
  if (last == null) return 'jamais cuisiné';
  final d = dateOnly(today).difference(dateOnly(last)).inDays;
  if (d < 7) return 'cette semaine';
  if (d < 14) return 'il y a $d j';
  if (d < 60) return 'il y a ${d ~/ 7} sem.';
  return 'il y a ${d ~/ 30} mois';
}
