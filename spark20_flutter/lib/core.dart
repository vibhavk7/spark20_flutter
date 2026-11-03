import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sb = Supabase.instance.client;

class C {
  static const cream = Color(0xFFFFFDF8), forest = Color(0xFF233B35), green = Color(0xFF246C59);
  static const muted = Color(0xFF687C74), border = Color(0xFFD9DED2), sand = Color(0xFFF1E7D8);
  static const coral = Color(0xFFEAC6BE), danger = Color(0xFFA9423A), sage = Color(0xFFE6E8D9);
  static const terracotta = Color(0xFFA95F4C), sun = Color(0xFFE6B69B), leaf = Color(0xFF4E7667);
}

TextStyle serif(double s, {Color? color, FontStyle? style, FontWeight w = FontWeight.w400}) =>
    GoogleFonts.fraunces(fontSize: s, color: color ?? C.forest, fontStyle: style, fontWeight: w, letterSpacing: -s * 0.02, height: 1.1);

ThemeData buildTheme() {
  final base = GoogleFonts.dmSansTextTheme().apply(bodyColor: C.forest, displayColor: C.forest);
  const pill = StadiumBorder();
  final pad = const EdgeInsets.symmetric(horizontal: 22, vertical: 14);
  OutlineInputBorder ob(Color c) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c));
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green, primary: C.green, surface: C.cream, error: C.danger),
    scaffoldBackgroundColor: C.cream,
    textTheme: base,
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: pill, padding: pad, backgroundColor: C.green, foregroundColor: Colors.white)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: pill, padding: pad, side: const BorderSide(color: C.border), foregroundColor: C.forest)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: pill, foregroundColor: C.green)),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: ob(C.border), enabledBorder: ob(C.border), focusedBorder: ob(C.green)),
    sliderTheme: const SliderThemeData(activeTrackColor: C.green, thumbColor: C.green),
    dialogTheme: DialogThemeData(backgroundColor: C.cream, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
  );
}

// ---------- app state ----------
class AppState extends ChangeNotifier {
  Map<String, dynamic>? profile, config;
  bool loaded = false, isAdmin = false;
  Future<void> load() async {
    final u = sb.auth.currentUser;
    try {
      config = await sb.from('spark20_business_settings').select().eq('id', 1).single();
      if (u == null) {
        profile = null; isAdmin = false;
      } else {
        profile = await sb.from('spark20_profiles').select().eq('user_id', u.id).maybeSingle();
        isAdmin = (await sb.rpc('s20_is_admin')) == true;
      }
    } catch (_) {}
    loaded = true;
    notifyListeners();
  }
  int get price => (config?['intro_price_paise'] ?? 2049) as int;
  int get reward => (config?['reply_reward_paise'] ?? 500) as int;
  int get minimumWithdrawalPaise => (config?['minimum_withdrawal_paise'] ?? 10000) as int;
}
final app = AppState();

// ---------- helpers ----------
String uid() => '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 31)}';
String inr(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2).format(paise / 100);
String when(dynamic s) => s == null ? '' : DateFormat('d MMM, h:mm a').format(DateTime.parse(s as String).toLocal());
List<Map<String, dynamic>> listOf(dynamic d) => ((d as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

String errText(Object e) {
  final m = e is PostgrestException ? e.message : e.toString();
  const map = {
    'profile_required': 'Please finish your profile first.',
    'not_eligible': 'This person isn’t available to you right now.',
    'payments_disabled': 'Introductions are paused while payments are disabled.',
    'already_matched': 'You’re already matched. Chat is free.',
    'rate_limited': 'A little slower, please. 20 messages a minute.',
    'forbidden': 'Moderators only.',
    'cannot_reply': 'Replies aren’t open for this introduction yet.',
    'cannot_decide': 'This introduction can’t be changed now.',
    'invalid_content': 'That message is empty or too long.',
    'location_required': 'Set and save your private location before filtering by radius.',
    'invalid_radius': 'Choose a radius between 1 and 500 km.',
  };
  for (final k in map.keys) { if (m.contains(k)) return map[k]!; }
  return m;
}
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
Future<T?> guard<T>(BuildContext c, Future<T> Function() f) async {
  try { return await f(); } catch (e) { if (c.mounted) toast(c, errText(e)); return null; }
}

// ---------- catalogs ----------
const kGenders = [
  ('woman', 'Woman'), ('man', 'Man'), ('non_binary', 'Non-binary'), ('trans_woman', 'Trans woman'),
  ('trans_man', 'Trans man'), ('genderfluid', 'Genderfluid'), ('agender', 'Agender'),
  ('prefer_not_to_say', 'Prefer not to say'), ('self_describe', 'Prefer to self-describe'),
];
const kFeed = [('women', 'Women'), ('men', 'Men'), ('non_binary', 'Non-binary people'), ('everyone', 'Everyone')];
const kGoals = [
  ('long_term', 'Long-term partner'), ('long_open_short', 'Long-term, open to short'),
  ('short_open_long', 'Short-term, open to long'), ('short_fun', 'Short-term fun'), ('figuring_out', 'Still figuring it out'),
];
String goalLabel(dynamic g) { final s = (g is List && g.isNotEmpty) ? g.first : g; for (final e in kGoals) { if (e.$1 == s) return e.$2; } return ''; }
String genderLabel(Map p) {
  if (p['genderIdentity'] == 'self_describe') return (p['genderIdentityCustom'] ?? 'Self-described').toString();
  for (final e in kGenders) { if (e.$1 == p['genderIdentity']) return e.$2; } return '';
}
const kInterests = [
  'Travel','Hiking','Camping','Road trips','Beach days','Mountains','Photography','Cooking','Baking','Coffee','Brunch','Fine dining','Street food','Wine','Craft beer','Cocktails','Fitness','Yoga','Pilates','Running',
  'Cycling','Swimming','Football','Cricket','Badminton','Tennis','Gym','Martial arts','Dancing','Clubbing','Live music','Concerts','Festivals','Karaoke','Movies','Anime','Reading','Writing','Poetry','Podcasts',
  'Stand-up comedy','Theatre','Art','Museums','Galleries','Design','Fashion','Thrifting','Shopping','Makeup','Skincare','Astrology','Spirituality','Meditation','Volunteering','Startups','Tech','Gaming','Board games','Chess',
  'Pets','Dogs','Cats','Plant parenting','Gardening','DIY','Cars','Motorcycles','Science','History','Languages','Learning','Career growth','Investing','Family','Picnics','Food tours','Spa days','Wellness','Sustainability',
  'Vegan cooking','True crime','K-pop','Bollywood','Indie music','IPL','Street photography','Nightlife','Quiet nights in','Boardgame cafes','Temples & heritage','Street markets','Cricket in the park','Morning walks','Late-night chai','Festival hopping','Photography walks','Cooking for others','Trying new cafes','Weekend getaways',
];

// ---------- widgets ----------
class Eyebrow extends StatelessWidget {
  final String t; const Eyebrow(this.t, {super.key});
  @override Widget build(BuildContext c) => Text(t.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, letterSpacing: 1.8, color: C.green, fontWeight: FontWeight.w700));
}
class SparkCard extends StatelessWidget {
  final Widget child; final EdgeInsets pad; final Color? color;
  const SparkCard({super.key, required this.child, this.pad = const EdgeInsets.all(18), this.color});
  @override Widget build(BuildContext c) => Container(
    margin: const EdgeInsets.only(bottom: 14), padding: pad,
    decoration: BoxDecoration(color: color ?? Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.border),
      boxShadow: const [BoxShadow(color: Color(0x0F233B35), blurRadius: 14, offset: Offset(0, 4))]),
    child: child);
}
class SparkChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback? onTap;
  const SparkChip(this.label, {super.key, this.selected = false, this.onTap});
  @override Widget build(BuildContext c) => InkWell(
    borderRadius: BorderRadius.circular(999), onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: selected ? C.green : Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? C.green : C.border)),
      child: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.white : C.forest))));
}
class Avatar extends StatelessWidget {
  final String name; final String? url; final double size;
  const Avatar(this.name, {super.key, this.url, this.size = 44});
  Widget _l() => Container(color: C.sage, alignment: Alignment.center, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: serif(size * .45)));
  @override Widget build(BuildContext c) => ClipOval(child: SizedBox(width: size, height: size,
    child: (url != null && url!.isNotEmpty) ? Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _l()) : _l()));
}
class Pad extends StatelessWidget {
  final List<Widget> children; const Pad(this.children, {super.key});
  @override Widget build(BuildContext c) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), children: children);
}
class AgeRangeField extends StatelessWidget {
  final RangeValues v; final ValueChanged<RangeValues> onChanged;
  const AgeRangeField(this.v, this.onChanged, {super.key});
  @override Widget build(BuildContext c) {
    final hi = v.end.round(); final label = '${v.start.round()} – ${hi >= 80 ? '80+' : hi}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: serif(22)),
      RangeSlider(values: v, min: 18, max: 80, divisions: 62, labels: RangeLabels('${v.start.round()}', '${v.end.round()}'), onChanged: onChanged),
      const Text('Both people’s ages need to fall in each other’s range. Private.', style: TextStyle(fontSize: 12, color: C.muted)),
    ]);
  }
}
class HeightRangeField extends StatelessWidget {
  final RangeValues v; final ValueChanged<RangeValues> onChanged;
  const HeightRangeField(this.v, this.onChanged, {super.key});
  @override Widget build(BuildContext c) {
    final low = v.start.round(); final high = v.end.round();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$low–$high cm', style: serif(22)),
      RangeSlider(values: v, min: 100, max: 250, divisions: 150,
        labels: RangeLabels('$low cm', '$high cm'), onChanged: onChanged),
      const Text('Both people’s listed heights need to fit each other’s range. Private.', style: TextStyle(fontSize: 12, color: C.muted)),
    ]);
  }
}
const kAgeNote = 'Spark20 is for adults 18+. Age is self-confirmed, not independently verified.';
void copy(BuildContext c, String t) { Clipboard.setData(ClipboardData(text: t)); toast(c, 'Copied'); }
