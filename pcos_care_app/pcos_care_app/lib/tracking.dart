import 'package:flutter/material.dart';
import 'analytics.dart' as an;
import 'db.dart';
import 'ui.dart';

// ======================================================================== CYCLES
class CyclesScreen extends StatelessWidget {
  final AppState s;
  const CyclesScreen(this.s, {super.key});

  Future<void> _edit(BuildContext context, Rec? row) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: CycleForm(s, row),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Rec>>(
      future: Db.list('cycles', s.pid!, desc: true),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        final asc = rows.reversed.toList();
        final lengths = an.cycleLengths(asc);
        final mean = an.meanOf(lengths);
        return ListView(padding: const EdgeInsets.all(16), children: [
          heading('Cycle Tracker'),
          FilledButton.icon(
              onPressed: () => _edit(context, null), icon: const Icon(Icons.add), label: const Text('Log a period')),
          gap,
          if (mean != null)
            card(Text('Average cycle length: ${mean.toStringAsFixed(0)} days across ${lengths.length} completed cycle(s). '
                'Calculated from your logged start dates.')),
          if (rows.isEmpty) emptyState('🩸', 'No periods logged yet', 'Tap "Log a period" to add your most recent period.'),
          for (var i = 0; i < rows.length; i++) _tile(context, rows, i),
          const Text('Tracking only. This app does not predict ovulation or fertile days.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
        ]);
      },
    );
  }

  Widget _tile(BuildContext context, List<Rec> rows, int i) {
    final r = rows[i];
    final start = parseIso(r['start_date'] as String);
    final end = r['end_date'] == null ? null : parseIso(r['end_date'] as String);
    String info = end == null ? 'End date not logged' : 'Bleeding ${end.difference(start).inDays + 1} day(s)';
    if (r['flow'] != null) info += ' · ${r['flow']}';
    String cycleInfo = 'Latest / in progress';
    if (i > 0) {
      final len = parseIso(rows[i - 1]['start_date'] as String).difference(start).inDays;
      cycleInfo = 'Cycle length $len days · ${an.patternLabel(len)}';
    }
    return card(InkWell(
      onTap: () => _edit(context, r),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(fmt(start), style: const TextStyle(fontWeight: FontWeight.w700, color: plum, fontSize: 16)),
        Text(info),
        Text(cycleInfo, style: const TextStyle(color: Color(0xFF7A6A85), fontSize: 12)),
        if (r['notes'] != null) Text('Note: ${r['notes']}'),
      ]),
    ));
  }
}

class CycleForm extends StatefulWidget {
  final AppState s;
  final Rec? row;
  const CycleForm(this.s, this.row, {super.key});
  @override
  State<CycleForm> createState() => _CycleFormState();
}

class _CycleFormState extends State<CycleForm> {
  late DateTime start;
  DateTime? end;
  String? flow;
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    start = r == null ? today() : parseIso(r['start_date'] as String);
    end = r?['end_date'] == null ? null : parseIso(r!['end_date'] as String);
    flow = r?['flow'] as String?;
    notes.text = (r?['notes'] as String?) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.row == null ? 'Log a period' : 'Edit period',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: plum)),
          gap,
          dateButton(context, 'Start date', start, (d) => setState(() => start = d)),
          gap,
          dateButton(context, 'End date (optional)', end, (d) => setState(() => end = d)),
          if (end != null) TextButton(onPressed: () => setState(() => end = null), child: const Text('Clear end date')),
          gap,
          DropdownButtonFormField<String?>(
            value: flow,
            decoration: deco('Flow (optional)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Not logged')),
              for (final f in flows) DropdownMenuItem<String?>(value: f, child: Text(f)),
            ],
            onChanged: (v) => setState(() => flow = v),
          ),
          gap,
          TextField(controller: notes, decoration: deco('Notes (optional)'), maxLines: 2),
          gap,
          FilledButton(
            onPressed: () => guard(context, () async {
              await Db.saveCycle(widget.s.pid!,
                  id: widget.row?['id'] as int?, start: start, end: end, flow: flow, notes: notes.text);
              widget.s.bump();
              if (context.mounted) Navigator.pop(context);
            }),
            child: const Text('Save'),
          ),
          if (widget.row != null)
            TextButton(
              onPressed: () async {
                if (await confirm(context, 'Delete this period entry?')) {
                  await Db.deleteRow('cycles', widget.s.pid!, widget.row!['id'] as int);
                  widget.s.bump();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Delete this entry', style: TextStyle(color: Colors.red)),
            ),
        ]),
      ),
    );
  }
}

// ===================================================================== SYMPTOMS
class SymptomsScreen extends StatefulWidget {
  final AppState s;
  const SymptomsScreen(this.s, {super.key});
  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  DateTime date = today();
  String symptom = symptomList.first;
  double severity = 3;
  final notes = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView(padding: const EdgeInsets.all(16), children: [
      heading('Symptom Tracker'),
      card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        dateButton(context, 'Date', date, (d) => setState(() => date = d)),
        gap,
        DropdownButtonFormField<String>(
          value: symptom,
          decoration: deco('Symptom'),
          items: [for (final x in symptomList) DropdownMenuItem(value: x, child: Text(x))],
          onChanged: (v) => setState(() => symptom = v ?? symptom),
        ),
        gap,
        Text('Severity: ${severity.round()} / 10 (1 = very mild, 10 = very severe)'),
        Slider(value: severity, min: 1, max: 10, divisions: 9, label: severity.round().toString(),
            onChanged: (v) => setState(() => severity = v)),
        TextField(controller: notes, decoration: deco('Notes (optional)')),
        gap,
        FilledButton(
          onPressed: () => guard(context, () async {
            await Db.saveSymptom(s.pid!, date, symptom, severity.round(), notes.text);
            notes.clear();
            s.bump();
            if (mounted) snack(context, 'Symptom saved');
          }),
          child: const Text('Save symptom'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Logging the same symptom twice on one day replaces the first entry.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
        ),
      ])),
      heading('Recent entries'),
      FutureBuilder<List<Rec>>(
        future: Db.list('symptoms', s.pid!, desc: true),
        builder: (context, snap) {
          final rows = (snap.data ?? []).take(30).toList();
          if (rows.isEmpty) return emptyState('🌡️', 'No symptoms logged yet', 'Your entries will show here.');
          return Column(children: [
            for (final r in rows)
              card(Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r['symptom']} · ${r['severity']}/10', style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(fmtIso(r['log_date'] as String), style: const TextStyle(fontSize: 12)),
                  if (r['notes'] != null) Text(r['notes'] as String),
                ])),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Delete this entry?')) {
                      await Db.deleteRow('symptoms', s.pid!, r['id'] as int);
                      s.bump();
                    }
                  },
                ),
              ])),
          ]);
        },
      ),
    ]);
  }
}

// ==================================================================== LIFESTYLE
class LifestyleScreen extends StatefulWidget {
  final AppState s;
  const LifestyleScreen(this.s, {super.key});
  @override
  State<LifestyleScreen> createState() => _LifestyleScreenState();
}

class _LifestyleScreenState extends State<LifestyleScreen> {
  DateTime date = today();
  final sleep = TextEditingController();
  final activity = TextEditingController();
  final water = TextEditingController();
  final weight = TextEditingController();
  final meals = TextEditingController();
  int? stress;

  TextField _num(TextEditingController c, String label) =>
      TextField(controller: c, decoration: deco(label), keyboardType: const TextInputType.numberWithOptions(decimal: true));

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView(padding: const EdgeInsets.all(16), children: [
      heading('Lifestyle Tracker'),
      card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        dateButton(context, 'Date', date, (d) => setState(() => date = d)),
        gap,
        _num(sleep, 'Sleep (hours)'),
        gap,
        _num(activity, 'Activity (minutes)'),
        gap,
        _num(water, 'Water (litres)'),
        gap,
        DropdownButtonFormField<int?>(
          value: stress,
          decoration: deco('Stress level (1 low - 10 high)'),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('Not logged')),
            for (var i = 1; i <= 10; i++) DropdownMenuItem<int?>(value: i, child: Text('$i')),
          ],
          onChanged: (v) => setState(() => stress = v),
        ),
        gap,
        _num(weight, 'Weight (kg, optional)'),
        gap,
        TextField(controller: meals, decoration: deco('Meals / diet notes (optional)')),
        gap,
        FilledButton(
          onPressed: () => guard(context, () async {
            await Db.saveLifestyle(s.pid!, date,
                sleep: sleep.text, activity: activity.text, water: water.text,
                stress: stress, weight: weight.text, meals: meals.text);
            for (final c in [sleep, activity, water, weight, meals]) {
              c.clear();
            }
            setState(() => stress = null);
            s.bump();
            if (mounted) snack(context, 'Saved');
          }),
          child: const Text('Save'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Every field is optional. Saving again for the same day replaces that day.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
        ),
      ])),
      heading('Recent entries'),
      FutureBuilder<List<Rec>>(
        future: Db.list('lifestyle', s.pid!, desc: true),
        builder: (context, snap) {
          final rows = (snap.data ?? []).take(14).toList();
          if (rows.isEmpty) return emptyState('🌙', 'No habits logged yet', 'Your entries will show here.');
          String v(Object? x, String unit) {
            if (x == null) return '-';
            final n = x as num;
            return '${n % 1 == 0 ? n.toInt() : n} $unit';
          }
          return Column(children: [
            for (final r in rows)
              card(Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtIso(r['log_date'] as String), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('Sleep ${v(r['sleep_hours'], 'h')} · Activity ${v(r['activity_min'], 'min')} · '
                      'Water ${v(r['water_l'], 'L')} · Stress ${r['stress'] ?? '-'}'),
                  if (r['weight_kg'] != null) Text('Weight ${v(r['weight_kg'], 'kg')}'),
                  if (r['meals'] != null) Text(r['meals'] as String),
                ])),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Delete this entry?')) {
                      await Db.deleteRow('lifestyle', s.pid!, r['id'] as int);
                      s.bump();
                    }
                  },
                ),
              ])),
          ]);
        },
      ),
    ]);
  }
}
