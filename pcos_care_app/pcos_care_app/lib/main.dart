import 'package:flutter/material.dart';
import 'analytics.dart' as an;
import 'care.dart';
import 'db.dart';
import 'education.dart';
import 'tracking.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PcosApp());
}

class PcosApp extends StatelessWidget {
  const PcosApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'PCOS CARE',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: plumSoft, surface: offWhite),
          scaffoldBackgroundColor: offWhite,
          appBarTheme: const AppBarTheme(backgroundColor: offWhite, foregroundColor: plum),
        ),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final s = AppState();
  int index = 0;

  @override
  void initState() {
    super.initState();
    s.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        if (s.loading) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final hasProfile = s.pid != null;
        return Scaffold(
          appBar: AppBar(
            title: const Text('🌸 PCOS CARE', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              const Text('Demo', style: TextStyle(fontSize: 12)),
              Switch(value: s.demo, onChanged: s.setDemo),
            ],
          ),
          body: Column(children: [
            if (s.demo) demoBanner(),
            Expanded(child: hasProfile ? _page() : (s.demo ? _DemoStart(s) : Onboarding(s))),
          ]),
          bottomNavigationBar: hasProfile
              ? NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => index = i),
                  destinations: const [
                    NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
                    NavigationDestination(icon: Icon(Icons.water_drop_outlined), label: 'Cycle'),
                    NavigationDestination(icon: Icon(Icons.thermostat), label: 'Symptoms'),
                    NavigationDestination(icon: Icon(Icons.nightlight_outlined), label: 'Habits'),
                    NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _page() {
    switch (index) {
      case 0:
        return Dashboard(s, goTo: (i) => setState(() => index = i));
      case 1:
        return CyclesScreen(s);
      case 2:
        return SymptomsScreen(s);
      case 3:
        return LifestyleScreen(s);
      default:
        return MoreScreen(s);
    }
  }
}

// ================================================================ DEMO START
class _DemoStart extends StatelessWidget {
  final AppState s;
  const _DemoStart(this.s);
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        heading('Demo mode'),
        const Text('Explore the app with a clearly labelled fictional patient and about five months of invented data. It never mixes with your own records.'),
        gap,
        FilledButton(
          onPressed: () => guard(context, () async {
            await Db.loadDemo();
            await s.refresh();
          }),
          child: const Text('Load demo data'),
        ),
      ]);
}

// ================================================================ ONBOARDING
class Onboarding extends StatefulWidget {
  final AppState s;
  const Onboarding(this.s, {super.key});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final name = TextEditingController();
  final age = TextEditingController();
  final goals = TextEditingController();
  String status = diagnosisStatus.first;
  bool consent = false;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      heading('Welcome 🌸'),
      const Text('PCOS CARE is a private tracking and education app. Your data stays on this phone. '
          'It does not diagnose PCOS or recommend treatment.'),
      gap,
      TextField(controller: name, decoration: deco('Name or nickname')),
      gap,
      TextField(controller: age, decoration: deco('Age'), keyboardType: TextInputType.number),
      gap,
      DropdownButtonFormField<String>(
        value: status,
        isExpanded: true,
        decoration: deco('Diagnosis status'),
        items: [for (final x in diagnosisStatus) DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))],
        onChanged: (v) => setState(() => status = v ?? status),
      ),
      gap,
      TextField(controller: goals, decoration: deco('Your goals (optional)'), maxLines: 2),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: consent,
        onChanged: (v) => setState(() => consent = v ?? false),
        title: const Text('I understand this app is for tracking and education only and stores my entries on this device.'),
      ),
      FilledButton(
        onPressed: () => guard(context, () async {
          if (!consent) throw ValidationError('Please tick the consent box to continue.');
          final a = int.tryParse(age.text.trim());
          if (a == null) throw ValidationError('Please enter your age as a number.');
          await Db.createPatient(name: name.text, age: a, status: status, goals: goals.text);
          await widget.s.refresh();
        }),
        child: const Text('Start'),
      ),
    ]);
  }
}

// ================================================================== DASHBOARD
class Dashboard extends StatelessWidget {
  final AppState s;
  final void Function(int) goTo;
  const Dashboard(this.s, {required this.goTo, super.key});

  Future<Map<String, List<Rec>>> _load() async {
    final pid = s.pid!;
    return {
      'cycles': await Db.list('cycles', pid),
      'symptoms': await Db.list('symptoms', pid, desc: true),
      'lifestyle': await Db.list('lifestyle', pid),
      'appointments': await Db.list('appointments', pid),
      'medications': await Db.list('medications', pid),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Rec>>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final cycles = d['cycles']!, symptoms = d['symptoms']!, life = d['lifestyle']!;
        final now = today();
        final lengths = an.cycleLengths(cycles);
        final mean = an.meanOf(lengths);
        final since = an.daysSinceLastPeriod(cycles, now);
        final ls = an.lifestyleSummary(life, now, 7);
        String f(double? v, String u) => v == null ? '-' : '${v.toStringAsFixed(1)} $u';
        final upcoming = d['appointments']!.where((x) {
          if (x['status'] != 'Upcoming') return false;
          final dt = parseIso(x['appt_date'] as String);
          return !dt.isBefore(now) && !dt.isAfter(addDays(now, 60));
        }).toList();
        final meds = d['medications']!.where((x) => x['active'] == 1 && x['reminder_time'] != null).toList();

        return ListView(padding: const EdgeInsets.all(16), children: [
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [plum, plumSoft, blushDeep]),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${s.patient?['pseudonym'] ?? ''} 🌸',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const Text('Your recorded data at a glance.', style: TextStyle(color: Colors.white)),
            ]),
          ),
          if (cycles.isEmpty && symptoms.isEmpty && life.isEmpty)
            emptyState('🌱', 'Nothing logged yet', 'Start with your most recent period. Every entry builds your picture.'),
          Row(children: [
            Expanded(
                child: metric('Last period', cycles.isEmpty ? 'Not logged' : fmtIso(cycles.last['start_date'] as String),
                    'From your cycle log')),
            const SizedBox(width: 8),
            Expanded(child: metric('Days since', since?.toString() ?? '-', 'Calculated from last start')),
          ]),
          metric('Average cycle length', mean == null ? '-' : '${mean.toStringAsFixed(0)} days',
              mean == null ? 'Needs at least 2 logged period starts' : 'Across ${lengths.length} completed cycles (calculated)'),
          Wrap(spacing: 8, children: [
            ActionChip(label: const Text('➕ Period'), onPressed: () => goTo(1)),
            ActionChip(label: const Text('➕ Symptoms'), onPressed: () => goTo(2)),
            ActionChip(label: const Text('➕ Habits'), onPressed: () => goTo(3)),
          ]),
          gap,
          if (lengths.isNotEmpty) _CycleBars(lengths.length > 8 ? lengths.sublist(lengths.length - 8) : lengths),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Recent symptoms', style: TextStyle(fontWeight: FontWeight.w800, color: plum)),
            const SizedBox(height: 4),
            if (symptoms.isEmpty) const Text('No symptoms logged yet.'),
            for (final r in symptoms.take(6))
              Text('${fmtIso(r['log_date'] as String)} · ${r['symptom']} ${r['severity']}/10'),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Last 7 days (averages)', style: TextStyle(fontWeight: FontWeight.w800, color: plum)),
            const SizedBox(height: 4),
            Text('Sleep: ${f(ls['sleep'], 'h')}'),
            Text('Activity: ${f(ls['activity'], 'min')}'),
            Text('Water: ${f(ls['water'], 'L')}'),
            Text('Stress: ${f(ls['stress'], '/10')}'),
            Text('Based on ${ls['days']!.toInt()} logged day(s)', style: const TextStyle(fontSize: 12)),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Upcoming reminders', style: TextStyle(fontWeight: FontWeight.w800, color: plum)),
            const SizedBox(height: 4),
            if (upcoming.isEmpty && meds.isEmpty) const Text('No upcoming appointments or medication reminders.'),
            for (final a in upcoming)
              Text('📅 ${fmtIso(a['appt_date'] as String)} ${a['appt_time'] ?? ''} · ${a['purpose'] ?? a['provider'] ?? 'Appointment'}'),
            for (final m in meds) Text('💊 ${m['name']}: daily at ${m['reminder_time']}'),
            const Text('Reminders show here while the app is open. They are not phone notifications.',
                style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
          ])),
          const Text('Tracking and education only. Not a diagnostic device.',
              style: TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
        ]);
      },
    );
  }
}

class _CycleBars extends StatelessWidget {
  final List<int> lengths;
  const _CycleBars(this.lengths);
  @override
  Widget build(BuildContext context) {
    final maxLen = lengths.reduce((a, b) => a > b ? a : b);
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Cycle length (days)', style: TextStyle(fontWeight: FontWeight.w800, color: plum)),
      const SizedBox(height: 8),
      SizedBox(
        height: 130,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final l in lengths)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('$l', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                Container(
                  height: 100.0 * l / maxLen,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: (l >= an.regularMin && l <= an.regularMax) ? plumSoft : blushDeep,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      const Text('Purple = within 21-35 days. Pink = outside that range. Oldest on the left.',
          style: TextStyle(fontSize: 11, color: Color(0xFF7A6A85))),
    ]));
  }
}

// ======================================================================== MORE
class MoreScreen extends StatelessWidget {
  final AppState s;
  const MoreScreen(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      heading('More'),
      _tile(context, '💊', 'Medications & Appointments', () => CareScreen(s)),
      _tile(context, '📚', 'Education Centre', () => const EducationScreen()),
      _tile(context, '⚙️', 'Settings & Privacy', () => SettingsScreen(s)),
      gap,
      urgentCard(),
    ]);
  }

  Widget _tile(BuildContext context, String icon, String title, Widget Function() page) => card(ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Text(icon, style: const TextStyle(fontSize: 24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: plum)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page())),
      ));
}

// =================================================================== SETTINGS
class SettingsScreen extends StatelessWidget {
  final AppState s;
  const SettingsScreen(this.s, {super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Privacy')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        card(const Text('🔒 Your data is stored only on this phone, in a private app database. '
            'Nothing is sent to any server. This app has no internet access.')),
        if (s.demo)
          FilledButton(
            onPressed: () => guard(context, () async {
              await Db.loadDemo();
              await s.refresh();
              if (context.mounted) snack(context, 'Demo data reset');
            }),
            child: const Text('Reset demo data'),
          )
        else ...[
          OutlinedButton(
            onPressed: () async {
              if (await confirm(context, 'Delete all your tracking records but keep your profile?')) {
                await Db.clearRecords(s.pid!);
                s.bump();
                if (context.mounted) snack(context, 'Records deleted');
              }
            },
            child: const Text('Delete all records (keep profile)'),
          ),
          gap,
          OutlinedButton(
            onPressed: () async {
              if (await confirm(context, 'Delete your profile and ALL your data? This cannot be undone.')) {
                await Db.deletePatient(s.pid!);
                await s.refresh();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Delete profile and all data', style: TextStyle(color: Colors.red)),
          ),
        ],
        gap,
        card(const Text('Tracking and education only. PCOS CARE does not diagnose PCOS, calculate diagnosis probabilities, '
            'predict ovulation, or recommend treatment or doses.')),
      ]),
    );
  }
}
