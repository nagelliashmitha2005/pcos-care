import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class ValidationError implements Exception {
  final String message;
  ValidationError(this.message);
  @override
  String toString() => message;
}

typedef Rec = Map<String, Object?>;

const flows = ['Spotting', 'Light', 'Medium', 'Heavy'];
const symptomList = [
  'Acne', 'Excess hair growth', 'Hair thinning', 'Pelvic discomfort',
  'Fatigue', 'Bloating', 'Mood changes', 'Sleep issues'
];
const diagnosisStatus = [
  'Diagnosed with PCOS by a healthcare professional',
  'Awaiting assessment or diagnosis',
  'Prefer not to say'
];
const apptStatus = ['Upcoming', 'Completed', 'Cancelled'];
const tableOrder = {
  'cycles': 'start_date',
  'symptoms': 'log_date',
  'lifestyle': 'log_date',
  'medications': 'name COLLATE NOCASE',
  'appointments': 'appt_date',
  'notes': 'note_date',
};

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseIso(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String? clean(String? s, {int max = 500}) {
  final v = (s ?? '').trim();
  if (v.length > max) throw ValidationError('Text is too long (maximum $max characters).');
  return v.isEmpty ? null : v;
}

double? parseNum(String s, String name, double lo, double hi) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final x = double.tryParse(v);
  if (x == null) throw ValidationError('$name must be a number.');
  if (x < lo || x > hi) throw ValidationError('$name must be between $lo and $hi.');
  return x;
}

double _gauss(Random r, double mu, double sigma) {
  final u1 = 1 - r.nextDouble();
  final u2 = r.nextDouble();
  return mu + sigma * sqrt(-2 * log(u1)) * cos(2 * pi * u2);
}

class Db {
  static Database? _db;

  static const _schema = <String>[
    '''CREATE TABLE patients(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      pseudonym TEXT NOT NULL, age INTEGER NOT NULL,
      diagnosis_status TEXT NOT NULL, diagnosis_date TEXT, cycle_history TEXT,
      health_info TEXT, goals TEXT, consent INTEGER NOT NULL,
      is_demo INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)''',
    '''CREATE TABLE cycles(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      start_date TEXT NOT NULL, end_date TEXT, flow TEXT, notes TEXT,
      UNIQUE(patient_id, start_date))''',
    '''CREATE TABLE symptoms(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      log_date TEXT NOT NULL, symptom TEXT NOT NULL,
      severity INTEGER NOT NULL, notes TEXT,
      UNIQUE(patient_id, log_date, symptom))''',
    '''CREATE TABLE lifestyle(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      log_date TEXT NOT NULL, sleep_hours REAL, activity_min REAL, water_l REAL,
      stress INTEGER, weight_kg REAL, meals TEXT, notes TEXT,
      UNIQUE(patient_id, log_date))''',
    '''CREATE TABLE medications(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      name TEXT NOT NULL, dosage_text TEXT, reminder_time TEXT,
      active INTEGER NOT NULL DEFAULT 1, notes TEXT)''',
    '''CREATE TABLE appointments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      appt_date TEXT NOT NULL, appt_time TEXT, provider TEXT, purpose TEXT,
      status TEXT NOT NULL DEFAULT 'Upcoming', notes TEXT)''',
    '''CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
      note_date TEXT NOT NULL, text TEXT NOT NULL)''',
  ];

  static Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'pcos_care.db');
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (d) async {
        await d.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (d, v) async {
        for (final s in _schema) {
          await d.execute(s);
        }
      },
    );
    return _db!;
  }

  // ---------------------------------------------------------------- patients
  static Future<int?> patientId(bool demo) async {
    final d = await db;
    final r = await d.query('patients',
        columns: ['id'], where: 'is_demo = ?', whereArgs: [demo ? 1 : 0], orderBy: 'id DESC', limit: 1);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  static Future<Rec?> patient(int id) async {
    final d = await db;
    final r = await d.query('patients', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  static Future<int> createPatient({
    required String name,
    required int age,
    required String status,
    String? cycleHistory,
    String? health,
    String? goals,
    bool demo = false,
  }) async {
    if (name.trim().isEmpty) throw ValidationError('Name or pseudonym is required.');
    if (age < 10 || age > 80) throw ValidationError('Age must be between 10 and 80.');
    final d = await db;
    return d.insert('patients', {
      'pseudonym': name.trim(),
      'age': age,
      'diagnosis_status': status,
      'cycle_history': cycleHistory,
      'health_info': clean(health, max: 1000),
      'goals': clean(goals),
      'consent': 1,
      'is_demo': demo ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deletePatient(int id) async {
    final d = await db;
    for (final t in tableOrder.keys) {
      await d.delete(t, where: 'patient_id = ?', whereArgs: [id]);
    }
    await d.delete('patients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> clearRecords(int id) async {
    final d = await db;
    for (final t in tableOrder.keys) {
      await d.delete(t, where: 'patient_id = ?', whereArgs: [id]);
    }
  }

  // ----------------------------------------------------------------- generic
  static Future<List<Rec>> list(String table, int pid, {bool desc = false}) async {
    final d = await db;
    return d.query(table,
        where: 'patient_id = ?',
        whereArgs: [pid],
        orderBy: '${tableOrder[table]} ${desc ? 'DESC' : 'ASC'}, id');
  }

  static Future<void> deleteRow(String table, int pid, int id) async {
    if (!tableOrder.containsKey(table)) throw ValidationError('Unknown record type.');
    final d = await db;
    await d.delete(table, where: 'id = ? AND patient_id = ?', whereArgs: [id, pid]);
  }

  // ------------------------------------------------------------------ cycles
  static Future<void> saveCycle(int pid,
      {int? id, required DateTime start, DateTime? end, String? flow, String? notes}) async {
    final t = today();
    if (start.isAfter(t)) throw ValidationError('Period start date cannot be in the future.');
    if (end != null) {
      if (end.isBefore(start)) throw ValidationError('The period end date cannot be before the start date.');
      if (end.isAfter(t)) throw ValidationError('Period end date cannot be in the future.');
      if (end.difference(start).inDays > 30) {
        throw ValidationError('Bleeding longer than 30 days looks like a typing error. Please check the dates.');
      }
    }
    final d = await db;
    final dup = await d.query('cycles',
        where: 'patient_id = ? AND start_date = ?', whereArgs: [pid, iso(start)]);
    if (dup.isNotEmpty && dup.first['id'] != id) {
      throw ValidationError('A period starting on this date is already logged. Edit that entry instead.');
    }
    final vals = <String, Object?>{
      'patient_id': pid,
      'start_date': iso(start),
      'end_date': end == null ? null : iso(end),
      'flow': flow,
      'notes': clean(notes),
    };
    if (id == null) {
      await d.insert('cycles', vals);
    } else {
      await d.update('cycles', vals, where: 'id = ? AND patient_id = ?', whereArgs: [id, pid]);
    }
  }

  // ---------------------------------------------------------------- symptoms
  static Future<void> saveSymptom(int pid, DateTime date, String symptom, int severity, String? notes) async {
    if (date.isAfter(today())) throw ValidationError('Date cannot be in the future.');
    if (severity < 1 || severity > 10) throw ValidationError('Severity must be between 1 and 10.');
    final d = await db;
    await d.insert(
        'symptoms',
        {
          'patient_id': pid,
          'log_date': iso(date),
          'symptom': symptom,
          'severity': severity,
          'notes': clean(notes),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --------------------------------------------------------------- lifestyle
  static Future<void> saveLifestyle(int pid, DateTime date,
      {String sleep = '',
      String activity = '',
      String water = '',
      int? stress,
      String weight = '',
      String? meals,
      String? notes}) async {
    if (date.isAfter(today())) throw ValidationError('Date cannot be in the future.');
    final vals = <String, Object?>{
      'sleep_hours': parseNum(sleep, 'Sleep', 0, 24),
      'activity_min': parseNum(activity, 'Activity minutes', 0, 1440),
      'water_l': parseNum(water, 'Water', 0, 15),
      'stress': stress,
      'weight_kg': parseNum(weight, 'Weight', 20, 400),
      'meals': clean(meals),
      'notes': clean(notes),
    };
    if (vals.values.every((v) => v == null)) {
      throw ValidationError('Enter at least one measurement or note. Every field is optional, but the entry cannot be empty.');
    }
    final d = await db;
    await d.insert('lifestyle', {'patient_id': pid, 'log_date': iso(date), ...vals},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ----------------------------------------------- medications / appts / notes
  static Future<void> saveMedication(int pid,
      {int? id, required String name, String? dosage, String? time, bool active = true, String? notes}) async {
    final n = clean(name, max: 100);
    if (n == null) throw ValidationError('Medication name is required.');
    final t = clean(time, max: 5);
    if (t != null && !RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(t)) {
      throw ValidationError('Reminder time must look like 14:30.');
    }
    final vals = <String, Object?>{
      'patient_id': pid,
      'name': n,
      'dosage_text': clean(dosage, max: 200),
      'reminder_time': t,
      'active': active ? 1 : 0,
      'notes': clean(notes),
    };
    final d = await db;
    if (id == null) {
      await d.insert('medications', vals);
    } else {
      await d.update('medications', vals, where: 'id = ? AND patient_id = ?', whereArgs: [id, pid]);
    }
  }

  static Future<void> saveAppointment(int pid,
      {int? id,
      required DateTime date,
      String? time,
      String? provider,
      String? purpose,
      String status = 'Upcoming',
      String? notes}) async {
    final t = clean(time, max: 5);
    if (t != null && !RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(t)) {
      throw ValidationError('Appointment time must look like 14:30.');
    }
    final vals = <String, Object?>{
      'patient_id': pid,
      'appt_date': iso(date),
      'appt_time': t,
      'provider': clean(provider, max: 100),
      'purpose': clean(purpose, max: 200),
      'status': status,
      'notes': clean(notes),
    };
    final d = await db;
    if (id == null) {
      await d.insert('appointments', vals);
    } else {
      await d.update('appointments', vals, where: 'id = ? AND patient_id = ?', whereArgs: [id, pid]);
    }
  }

  static Future<void> saveNote(int pid, {int? id, required DateTime date, required String text}) async {
    final t = clean(text, max: 2000);
    if (t == null) throw ValidationError('Note is required.');
    if (date.isAfter(today())) throw ValidationError('Note date cannot be in the future.');
    final vals = <String, Object?>{'patient_id': pid, 'note_date': iso(date), 'text': t};
    final d = await db;
    if (id == null) {
      await d.insert('notes', vals);
    } else {
      await d.update('notes', vals, where: 'id = ? AND patient_id = ?', whereArgs: [id, pid]);
    }
  }

  // --------------------------------------------------------------- demo data
  static Future<int> loadDemo() async {
    final old = await patientId(true);
    if (old != null) await deletePatient(old);
    final rng = Random(42);
    final t = today();
    final pid = await createPatient(
      name: 'Demo Patient (fictional)',
      age: 24,
      status: diagnosisStatus[0],
      cycleHistory: 'Often longer than 35 days',
      health: 'FICTIONAL demo profile. No real person.',
      goals: 'Understand my cycle patterns; keep better notes for appointments.',
      demo: true,
    );
    final d = await db;
    final b = d.batch();

    final starts = <DateTime>[addDays(t, -12)];
    for (final l in [38, 31, 44, 35, 40]) {
      starts.add(addDays(starts.last, -l));
    }
    starts.sort();
    const flowChoices = ['Light', 'Medium', 'Medium', 'Heavy'];
    for (final s in starts) {
      final bleed = 4 + rng.nextInt(3);
      b.insert('cycles', {
        'patient_id': pid,
        'start_date': iso(s),
        'end_date': iso(addDays(s, bleed - 1)),
        'flow': flowChoices[rng.nextInt(4)],
        'notes': rng.nextDouble() < 0.3 ? 'Demo entry' : null,
      });
    }

    bool nearPeriod(DateTime day) => starts.any((s) {
          final diff = day.difference(s).inDays;
          return diff >= -3 && diff <= 2;
        });
    const weights = {
      'Acne': 4, 'Fatigue': 4, 'Bloating': 3, 'Mood changes': 3,
      'Sleep issues': 2, 'Hair thinning': 1, 'Excess hair growth': 1, 'Pelvic discomfort': 2,
    };
    final total = weights.values.reduce((a, c) => a + c);
    String pickSym() {
      var r = rng.nextInt(total);
      for (final e in weights.entries) {
        if (r < e.value) return e.key;
        r -= e.value;
      }
      return 'Acne';
    }

    const periodSyms = ['Pelvic discomfort', 'Fatigue', 'Bloating', 'Mood changes'];
    const mealChoices = <String?>['Home-cooked lunch', 'Skipped breakfast', 'Lentils and rice', null, null];
    var w = 68.0;
    for (var i = 150; i >= 0; i--) {
      final day = addDays(t, -i);
      if (rng.nextDouble() < 0.38) {
        final k = 1 + rng.nextInt(2);
        final picked = <String>{for (var j = 0; j < k; j++) pickSym()};
        for (final sym in picked) {
          var sev = 2 + rng.nextInt(5);
          if (nearPeriod(day) && periodSyms.contains(sym)) sev += 2;
          b.insert(
              'symptoms',
              {'patient_id': pid, 'log_date': iso(day), 'symptom': sym, 'severity': min(sev, 9)},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      if (rng.nextDouble() < 0.85) {
        final sleep = _gauss(rng, 7.0, 0.9).clamp(4.5, 9.5).toDouble();
        final stress = (9 - sleep + _gauss(rng, 0, 1.2)).round().clamp(1, 10).toInt();
        w += _gauss(rng, 0, 0.15);
        b.insert(
            'lifestyle',
            {
              'patient_id': pid,
              'log_date': iso(day),
              'sleep_hours': (sleep * 4).round() / 4,
              'activity_min': _gauss(rng, 35, 20).clamp(0, 120).round().toDouble(),
              'water_l': (_gauss(rng, 2.0, 0.5).clamp(0.5, 3.5) * 10).round() / 10,
              'stress': stress,
              'weight_kg': i % 7 == 0 ? (w * 10).round() / 10 : null,
              'meals': mealChoices[rng.nextInt(mealChoices.length)],
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    b.insert('medications', {
      'patient_id': pid, 'name': 'Vitamin D (demo entry)',
      'dosage_text': 'As entered by patient: 1 tablet with breakfast', 'reminder_time': '08:30', 'active': 1,
    });
    b.insert('medications', {
      'patient_id': pid, 'name': 'Example prescription (demo entry)',
      'dosage_text': 'As written on the fictional prescription', 'reminder_time': '21:00', 'active': 1,
    });
    b.insert('appointments', {
      'patient_id': pid, 'appt_date': iso(addDays(t, -20)), 'appt_time': '10:30',
      'provider': 'Dr. Example (fictional)', 'purpose': 'Routine review', 'status': 'Completed',
    });
    b.insert('appointments', {
      'patient_id': pid, 'appt_date': iso(addDays(t, 14)), 'appt_time': '15:00',
      'provider': 'Dr. Example (fictional)', 'purpose': 'Review cycle log and symptoms', 'status': 'Upcoming',
    });
    b.insert('notes', {
      'patient_id': pid, 'note_date': iso(addDays(t, -5)),
      'text': 'Demo note: ask about long gaps between periods.',
    });
    await b.commit(noResult: true);
    return pid;
  }
}
