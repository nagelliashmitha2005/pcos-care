import 'package:flutter/material.dart';
import 'ui.dart';

const disclaimer =
    'This information is educational and not a substitute for advice from a doctor or other qualified '
    'healthcare professional. PCOS varies a lot from person to person.';

const urgent = [
  'Severe or sudden pelvic or abdominal pain, especially with fever, vomiting or fainting',
  'Very heavy bleeding (for example soaking through a pad or tampon every hour for several hours) or bleeding with dizziness, faintness or a racing heart',
  'Chest pain, difficulty breathing, or pain/swelling in one leg',
  'Thoughts of harming yourself. Please contact local emergency services or a crisis line straight away',
  'A positive pregnancy test with pain or bleeding',
];

const sections = <List<String>>[
  [
    '🌸 PCOS basics',
    'Polycystic ovary syndrome (PCOS) is a common hormonal condition that affects many people with ovaries, mainly during the reproductive years. It is not defined by having cysts. The name is historical.\n\nPCOS shows up differently in different people. Some notice irregular or infrequent periods; others notice acne, extra hair growth, scalp hair thinning, or changes in weight, energy or mood. Your experience may differ from anyone else\'s, and it can change over time.'
  ],
  [
    '🔍 Common symptoms',
    'Symptoms that people with PCOS may notice include:\n• Irregular, infrequent or absent periods\n• Acne, oily skin, extra facial or body hair or scalp hair thinning\n• Fatigue, bloating, mood changes, sleep problems\n• Difficulty conceiving in some people\n\nMany of these also have other causes (for example thyroid conditions), which is why a clinician needs to assess them. Having one or more symptoms does not mean you have PCOS.'
  ],
  [
    '🩺 How PCOS is diagnosed',
    'Diagnosis is made by a healthcare professional, not by an app. In adults the 2023 international guideline describes needing irregular cycles together with either signs of raised androgens (clinical or blood tests) or polycystic-appearing ovaries on ultrasound (an anti-Mullerian hormone blood test may be used instead of ultrasound in adults), after other conditions with similar features have been excluded.\n\nCycle logs like the one in this app can be a helpful record to bring to an appointment.'
  ],
  [
    '🌿 Lifestyle and everyday health',
    'Guidelines support healthy lifestyle habits for everyone with PCOS: regular movement you enjoy, balanced and sufficient eating, good sleep and ways of managing stress. There is no single "PCOS diet", and restrictive dieting is not recommended as a general approach. Health is not measured by weight alone.\n\nAny changes to eating, exercise or medicines are best discussed with your healthcare team.'
  ],
  [
    '📅 Menstrual health',
    'Cycle length is counted from the first day of one period to the first day of the next. A commonly used adult range is 21 to 35 days. Cycles can vary, and variation is common with PCOS.\n\nWhy this app does not predict ovulation or fertile days: with irregular cycles, ovulation timing is unpredictable and calendar-based estimates can be wrong. Please do not use this app for contraception or conception planning.'
  ],
  [
    '💬 Fertility: myths and facts',
    '• Myth: "PCOS means I can\'t get pregnant." Fact: PCOS can make ovulation less regular, so conceiving may take longer for some people, but many people with PCOS conceive, with or without support.\n• Myth: "Irregular periods mean I can\'t ovulate." Fact: Ovulation may still happen, just unpredictably. If you do not want to become pregnant, ask a clinician about contraception.\n• If you are trying to conceive, a healthcare professional can give personalised guidance.'
  ],
  [
    '❤️ Metabolic and long-term health',
    'PCOS is associated with a higher chance of insulin resistance, type 2 diabetes, high blood pressure, cholesterol changes, sleep apnoea, and with anxiety and low mood. These are risks that clinicians check for, not certainties. Regular check-ups (such as blood pressure, blood glucose and cholesterol tests, as advised by your clinician) are useful.'
  ],
];

Widget urgentCard() => card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Get urgent medical care if you have:',
            style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF7A1F27))),
        const SizedBox(height: 4),
        for (final u in urgent) Padding(padding: const EdgeInsets.only(top: 3), child: Text('• $u', style: const TextStyle(color: Color(0xFF7A1F27)))),
      ]),
      color: const Color(0xFFFFF1F1),
    );

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Education Centre')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(disclaimer, style: const TextStyle(fontSize: 12, color: Color(0xFF7A6A85))),
        gap,
        urgentCard(),
        for (final sec in sections)
          card(ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(sec[0], style: const TextStyle(fontWeight: FontWeight.w700, color: plum)),
            children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(sec[1]))],
          )),
      ]),
    );
  }
}
