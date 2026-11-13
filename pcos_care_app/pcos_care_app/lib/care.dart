import 'package:flutter/material.dart';
import 'db.dart';
import 'ui.dart';

class CareScreen extends StatelessWidget {
  final AppState s;
  const CareScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medications & Appointments'),
          bottom: const TabBar(tabs: [Tab(text: 'Medications'), Tab(text: 'Appointments'), Tab(text: 'Notes')]),
        ),
        body: TabBarView(children: [_Meds(s), _Appts(s), _Notes(s)]),
      ),
    );
  }
}

Future<void> _sheet(BuildContext context, Widget form) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: form)),
      ),
    );

// ------------------------------------------------------------------ medications
class _Meds extends StatefulWidget {
  final AppState s;
  const _Meds(this.s);
  @override
  State<_Meds> createState() => _MedsState();
}

class _MedsState extends State<_Meds> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FutureBuilder<List<Rec>>(
      future: Db.list('medications', s.pid!),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          FilledButton.icon(
              onPressed: () async {
                await _sheet(context, _MedForm(s, null));
                setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Add medication')),
          gap,
          const Text('Entries are written by you. The app never suggests medicines or doses. Reminders show in the app only (not phone notifications).',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
          gap,
          if (rows.isEmpty) emptyState('💊', 'No medications added', 'Add anything you want to keep track of.'),
          for (final r in rows)
            card(InkWell(
              onTap: () async {
                await _sheet(context, _MedForm(s, r));
                setState(() {});
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r['name']}${r['active'] == 1 ? '' : ' (inactive)'}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: plum)),
                if (r['dosage_text'] != null) Text(r['dosage_text'] as String),
                if (r['reminder_time'] != null) Text('Daily reminder at ${r['reminder_time']}'),
                if (r['notes'] != null) Text(r['notes'] as String),
              ]),
            )),
        ]);
      },
    );
  }
}

class _MedForm extends StatefulWidget {
  final AppState s;
  final Rec? row;
  const _MedForm(this.s, this.row);
  @override
  State<_MedForm> createState() => _MedFormState();
}

class _MedFormState extends State<_MedForm> {
  final name = TextEditingController();
  final dosage = TextEditingController();
  final time = TextEditingController();
  final notes = TextEditingController();
  bool active = true;

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r != null) {
      name.text = r['name'] as String;
      dosage.text = (r['dosage_text'] as String?) ?? '';
      time.text = (r['reminder_time'] as String?) ?? '';
      notes.text = (r['notes'] as String?) ?? '';
      active = r['active'] == 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.row == null ? 'Add medication' : 'Edit medication',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: plum)),
      gap,
      TextField(controller: name, decoration: deco('Name')),
      gap,
      TextField(controller: dosage, decoration: deco('Dosage instructions (as written on your prescription)')),
      gap,
      TextField(controller: time, decoration: deco('Daily reminder time (optional)', hint: '08:30')),
      gap,
      TextField(controller: notes, decoration: deco('Notes (optional)')),
      SwitchListTile(title: const Text('Active'), value: active, onChanged: (v) => setState(() => active = v)),
      FilledButton(
        onPressed: () => guard(context, () async {
          await Db.saveMedication(widget.s.pid!,
              id: widget.row?['id'] as int?, name: name.text, dosage: dosage.text,
              time: time.text, active: active, notes: notes.text);
          widget.s.bump();
          if (context.mounted) Navigator.pop(context);
        }),
        child: const Text('Save'),
      ),
      if (widget.row != null)
        TextButton(
          onPressed: () async {
            if (await confirm(context, 'Delete this medication?')) {
              await Db.deleteRow('medications', widget.s.pid!, widget.row!['id'] as int);
              widget.s.bump();
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
    ]);
  }
}

// ----------------------------------------------------------------- appointments
class _Appts extends StatefulWidget {
  final AppState s;
  const _Appts(this.s);
  @override
  State<_Appts> createState() => _ApptsState();
}

class _ApptsState extends State<_Appts> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return FutureBuilder<List<Rec>>(
      future: Db.list('appointments', s.pid!, desc: true),
      builder: (context, snap) {
        final rows = snap.data ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          FilledButton.icon(
              onPressed: () async {
                await _sheet(context, _ApptForm(s, null));
                setState(() {});
              },
              icon: const Icon(Icons.add),
              label: const Text('Add appointment')),
          gap,
          if (rows.isEmpty) emptyState('📅', 'No appointments yet', 'Add upcoming or past visits.'),
          for (final r in rows)
            card(InkWell(
              onTap: () async {
                await _sheet(context, _ApptForm(s, r));
                setState(() {});
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${fmtIso(r['appt_date'] as String)} ${r['appt_time'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: plum)),
                Text('${r['purpose'] ?? r['provider'] ?? 'Appointment'} · ${r['status']}'),
                if (r['provider'] != null && r['purpose'] != null) Text(r['provider'] as String),
              ]),
            )),
        ]);
      },
    );
  }
}

class _ApptForm extends StatefulWidget {
  final AppState s;
  final Rec? row;
  const _ApptForm(this.s, this.row);
  @override
  State<_ApptForm> createState() => _ApptFormState();
}

class _ApptFormState extends State<_ApptForm> {
  DateTime date = today();
  String status = 'Upcoming';
  final time = TextEditingController();
  final provider = TextEditingController();
  final purpose = TextEditingController();
  final notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.row;
    if (r != null) {
      date = parseIso(r['appt_date'] as String);
      status = r['status'] as String;
      time.text = (r['appt_time'] as String?) ?? '';
      provider.text = (r['provider'] as String?) ?? '';
      purpose.text = (r['purpose'] as String?) ?? '';
      notes.text = (r['notes'] as String?) ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(widget.row == null ? 'Add appointment' : 'Edit appointment',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: plum)),
      gap,
      dateButton(context, 'Date', date, (d) => setState(() => date = d),
          first: DateTime(2000), last: DateTime(2100)),
      gap,
      TextField(controller: time, decoration: deco('Time (optional)', hint: '15:00')),
      gap,
      TextField(controller: provider, decoration: deco('Doctor / clinic (optional)')),
      gap,
      TextField(controller: purpose, decoration: deco('Purpose (optional)')),
      gap,
      DropdownButtonFormField<String>(
        value: status,
        decoration: deco('Status'),
        items: [for (final x in apptStatus) DropdownMenuItem(value: x, child: Text(x))],
        onChanged: (v) => setState(() => status = v ?? status),
      ),
      gap,
      TextField(controller: notes, decoration: deco('Notes (optional)')),
      gap,
      FilledButton(
        onPressed: () => guard(context, () async {
          await Db.saveAppointment(widget.s.pid!,
              id: widget.row?['id'] as int?, date: date, time: time.text, provider: provider.text,
              purpose: purpose.text, status: status, notes: notes.text);
          widget.s.bump();
          if (context.mounted) Navigator.pop(context);
        }),
        child: const Text('Save'),
      ),
      if (widget.row != null)
        TextButton(
          onPressed: () async {
            if (await confirm(context, 'Delete this appointment?')) {
              await Db.deleteRow('appointments', widget.s.pid!, widget.row!['id'] as int);
              widget.s.bump();
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
    ]);
  }
}

// ------------------------------------------------------------------------ notes
class _Notes extends StatefulWidget {
  final AppState s;
  const _Notes(this.s);
  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  final text = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(controller: text, decoration: deco('Write a note for your next appointment'), maxLines: 3),
      gap,
      FilledButton(
        onPressed: () => guard(context, () async {
          await Db.saveNote(s.pid!, date: today(), text: text.text);
          text.clear();
          s.bump();
          setState(() {});
        }),
        child: const Text('Save note'),
      ),
      gap,
      FutureBuilder<List<Rec>>(
        future: Db.list('notes', s.pid!, desc: true),
        builder: (context, snap) {
          final rows = snap.data ?? [];
          if (rows.isEmpty) return emptyState('📝', 'No notes yet', 'Questions or observations you want to remember.');
          return Column(children: [
            for (final r in rows)
              card(Row(children: [
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtIso(r['note_date'] as String), style: const TextStyle(fontSize: 12, color: plumSoft)),
                  Text(r['text'] as String),
                ])),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, 'Delete this note?')) {
                      await Db.deleteRow('notes', s.pid!, r['id'] as int);
                      s.bump();
                      setState(() {});
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
