import 'package:flutter/material.dart';
import 'db.dart';

const plum = Color(0xFF4A1D5C);
const plumSoft = Color(0xFF7B3F98);
const lavender = Color(0xFFE6E0F8);
const blush = Color(0xFFF9DDE6);
const blushDeep = Color(0xFFE58FB0);
const offWhite = Color(0xFFFBF8FC);
const ink = Color(0xFF3B1F4A);

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
String fmtIso(String s) => fmt(parseIso(s));

/// Shared app state: which data set is shown (own records or demo) and a counter that
/// changes whenever data is saved so screens reload.
class AppState extends ChangeNotifier {
  bool demo = false;
  bool loading = true;
  int? pid;
  Rec? patient;
  int version = 0;

  Future<void> refresh() async {
    pid = await Db.patientId(demo);
    patient = pid == null ? null : await Db.patient(pid!);
    loading = false;
    version++;
    notifyListeners();
  }

  void setDemo(bool v) {
    demo = v;
    refresh();
  }

  void bump() {
    version++;
    notifyListeners();
  }
}

Widget card(Widget child, {Color color = Colors.white}) => Card(
      elevation: 0,
      color: color,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: lavender),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: SizedBox(width: double.infinity, child: child)),
    );

Widget metric(String label, String value, String sub) => card(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: plumSoft, letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: plum)),
        Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
      ],
    ));

Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: plum)),
    );

Widget emptyState(String emoji, String title, String text) => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB9A7E8), width: 1.5),
      ),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: plum)),
        const SizedBox(height: 4),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: ink)),
      ]),
    );

void snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

/// Runs [fn] and shows friendly messages for validation errors.
Future<void> guard(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } on ValidationError catch (e) {
    if (c.mounted) snack(c, e.message);
  } catch (e) {
    if (c.mounted) snack(c, 'Something went wrong: $e');
  }
}

Future<bool> confirm(BuildContext c, String message) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
      ],
    ),
  );
  return r ?? false;
}

Widget dateButton(BuildContext c, String label, DateTime? value, ValueChanged<DateTime> onPick,
    {DateTime? first, DateTime? last}) {
  return OutlinedButton.icon(
    icon: const Icon(Icons.calendar_today, size: 18),
    label: Text('$label: ${value == null ? 'not set' : fmt(value)}'),
    onPressed: () async {
      final picked = await showDatePicker(
        context: c,
        initialDate: value ?? today(),
        firstDate: first ?? DateTime(1990),
        lastDate: last ?? today(),
      );
      if (picked != null) onPick(DateTime(picked.year, picked.month, picked.day));
    },
  );
}

InputDecoration deco(String label, {String? hint}) =>
    InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true);

const gap = SizedBox(height: 12);

Widget demoBanner() => Container(
      width: double.infinity,
      color: blushDeep,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: const Text('DEMO MODE - FICTIONAL DATA',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
    );
