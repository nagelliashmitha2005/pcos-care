import 'db.dart';

const regularMin = 21;
const regularMax = 35;

/// Cycle lengths (start to next start), oldest first. [cycles] must be sorted ascending by start date.
List<int> cycleLengths(List<Rec> cycles) {
  final out = <int>[];
  for (var i = 0; i < cycles.length - 1; i++) {
    out.add(parseIso(cycles[i + 1]['start_date'] as String)
        .difference(parseIso(cycles[i]['start_date'] as String))
        .inDays);
  }
  return out;
}

double? meanOf(List<num> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;

int? daysSinceLastPeriod(List<Rec> cycles, DateTime now) {
  DateTime? latest;
  for (final c in cycles) {
    final s = parseIso(c['start_date'] as String);
    if (!s.isAfter(now) && (latest == null || s.isAfter(latest))) latest = s;
  }
  return latest == null ? null : now.difference(latest).inDays;
}

String patternLabel(int length) {
  if (length < regularMin) return 'Shorter than 21 days';
  if (length > 90) return 'Longer than 90 days';
  if (length > regularMax) return 'Longer than 35 days';
  return 'Within 21-35 days';
}

/// Averages of logged lifestyle values in the last [days] days.
Map<String, double?> lifestyleSummary(List<Rec> life, DateTime now, int days) {
  final from = addDays(now, -(days - 1));
  final recent = life.where((r) {
    final d = parseIso(r['log_date'] as String);
    return !d.isBefore(from) && !d.isAfter(now);
  }).toList();
  double? avg(String k) =>
      meanOf(recent.where((r) => r[k] != null).map((r) => (r[k] as num)).toList());
  return {
    'sleep': avg('sleep_hours'),
    'activity': avg('activity_min'),
    'water': avg('water_l'),
    'stress': avg('stress'),
    'days': recent.length.toDouble(),
  };
}
