import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core.dart';
import 'intros.dart';
import 'safety.dart';

class DiscoverScreen extends StatefulWidget { const DiscoverScreen({super.key}); @override State<DiscoverScreen> createState() => _S(); }
class _S extends State<DiscoverScreen> {
  List<Map<String, dynamic>> queue = []; bool loading = true; int pi = 0; double radiusKm = 50; final cityC = TextEditingController();
  bool get hasPrivateLocation => app.profile?['location_enabled'] == true &&
      app.profile?['latitude'] != null && app.profile?['longitude'] != null;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() => loading = true);
    final r = await guard(context, () => sb.rpc('s20_discovery', params: {
      'p_city': cityC.text.trim().isEmpty ? null : cityC.text.trim(),
      'p_limit': 12,
      'p_radius_km': hasPrivateLocation ? radiusKm.round() : null,
    }));
    if (mounted) setState(() { queue = listOf(r); loading = false; pi = 0; });
  }
  Future<void> act(String a) async {
    final p = queue.first;
    final r = await guard(context, () => sb.rpc('s20_like', params: {'p_target': p['id'], 'p_action': a}));
    if (r == null) return;
    if (!mounted) return;
    setState(() { queue.removeAt(0); pi = 0; });
    final m = Map<String, dynamic>.from(r as Map);
    if (m['matched'] == true) {
      toast(context, 'It’s mutual. You have a new match.');
    }
    if (queue.isEmpty) load();
  }
  Widget card(Map<String, dynamic> p) {
    final photos = List<String>.from(p['photoUrls']);
    return SparkCard(pad: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), child: SizedBox(height: 380, width: double.infinity,
        child: photos.isEmpty ? Container(color: C.sage, child: Center(child: Avatar(p['displayName'], size: 140)))
          : Stack(children: [PageView(onPageChanged: (i) => setState(() => pi = i), children: [for (final u in photos) Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: C.sage))]),
              if (photos.length > 1) Positioned(top: 10, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0x88000000), borderRadius: BorderRadius.circular(99)), child: Text('${pi + 1}/${photos.length}', style: const TextStyle(color: Colors.white, fontSize: 12))))]))),
      Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${p['displayName']}, ${p['age']}', style: serif(30))),
          PopupMenuButton<String>(onSelected: (_) => showReportDialog(context, targetId: p['id'], name: p['displayName']), itemBuilder: (_) => const [PopupMenuItem(value: 'r', child: Text('Report or block'))])]),
        Text('${p['city']} · ${genderLabel(p)}${p['heightCm'] == null ? '' : ' · ${p['heightCm']} cm'}', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 6), Text(goalLabel(p['relationshipGoals']), style: const TextStyle(color: C.green, fontWeight: FontWeight.w600)),
        if ((p['bio'] as String).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(p['bio'], style: const TextStyle(height: 1.4))),
        const SizedBox(height: 12), Wrap(spacing: 6, runSpacing: 6, children: [for (final i in List<String>.from(p['interests'])) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(99)), child: Text(i, style: const TextStyle(fontSize: 12)))]),
        const SizedBox(height: 12), const Text('Only their city is shown. Exact location is never shared.', style: TextStyle(fontSize: 11, color: C.muted)),
      ])),
    ]));
  }
  @override Widget build(BuildContext c) => Pad([
    const Eyebrow('Discover'), Text('One person at a time.', style: serif(34)), const SizedBox(height: 10),
    TextField(controller: cityC, onSubmitted: (_) => load(), decoration: InputDecoration(hintText: 'Filter by city (optional)', suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: load))),
    const SizedBox(height: 14),
    Row(children: [Expanded(child: Text(hasPrivateLocation ? 'Within ${radiusKm.round()} km' : 'Radius filter needs a private location', style: const TextStyle(fontWeight: FontWeight.w600))),
      if (!hasPrivateLocation) TextButton(onPressed: () => c.go('/profile'), child: const Text('Set location'))]),
    Slider(value: radiusKm, min: 5, max: 200, divisions: 39,
      label: '${radiusKm.round()} km', onChanged: hasPrivateLocation ? (v) => setState(() => radiusKm = v) : null,
      onChangeEnd: hasPrivateLocation ? (_) => load() : null),
    if (hasPrivateLocation) const Text('Only profiles that also enabled private location filtering can be radius-matched.', style: TextStyle(fontSize: 11, color: C.muted)),
    const SizedBox(height: 14),
    if (loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
    else if (queue.isEmpty) SparkCard(child: Column(children: [Text('That’s everyone for now.', style: serif(26)), const SizedBox(height: 8), const Text('Check back a little later. No rush.', style: TextStyle(color: C.muted)), const SizedBox(height: 12), OutlinedButton(onPressed: load, child: const Text('Look again'))]))
    else ...[
      card(queue.first),
      Row(children: [
        Expanded(child: OutlinedButton(key: const Key('pass'), onPressed: () => act('pass'), child: const Text('Pass'))), const SizedBox(width: 12),
        Expanded(child: FilledButton(key: const Key('like'), onPressed: () => act('like'), child: const Text('Like')))]),
      const Center(child: Text('Direct introductions are paused until verified payments are configured.', style: TextStyle(fontSize: 12, color: C.muted))),
    ],
  ]);
}
