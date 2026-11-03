import 'package:flutter/material.dart';
import '../core.dart';

const kCats = ['harassment', 'scam', 'threats', 'impersonation', 'explicit_content', 'underage_concern', 'other'];

Future<void> showReportDialog(BuildContext c, {required String targetId, String? name, String? introId}) async {
  String cat = 'harassment'; final d = TextEditingController();
  await showDialog(context: c, builder: (dc) => StatefulBuilder(builder: (dc, set) => AlertDialog(
    title: Text('Report or block ${name ?? ''}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(value: cat, items: [for (final k in kCats) DropdownMenuItem(value: k, child: Text(k.replaceAll('_', ' ')))], onChanged: (v) => set(() => cat = v!)),
      const SizedBox(height: 10), TextField(controller: d, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(hintText: 'Anything a moderator should know (optional)')),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancel')),
      TextButton(key: const Key('block'), onPressed: () async {
        final r = await guard(c, () => sb.rpc('s20_block', params: {'p_target': targetId}));
        if (dc.mounted) Navigator.pop(dc); if (c.mounted) toast(c, 'Blocked. They won’t appear anywhere for you.'); },
        child: const Text('Block', style: TextStyle(color: C.danger))),
      FilledButton(key: const Key('report-submit'), onPressed: () async {
        await guard(c, () => sb.rpc('s20_report', params: {'p_target': targetId, 'p_category': cat, 'p_details': d.text, 'p_intro': introId}));
        if (dc.mounted) Navigator.pop(dc); if (c.mounted) toast(c, 'Thank you. A moderator will take a look.'); },
        child: const Text('Report')),
    ])));
}

class SafetyScreen extends StatefulWidget { const SafetyScreen({super.key}); @override State<SafetyScreen> createState() => _S(); }
class _S extends State<SafetyScreen> {
  List<Map<String, dynamic>> people = []; String? target;
  @override void initState() { super.initState(); guard(context, () async { final r = await sb.rpc('s20_matches'); if (mounted) setState(() { people = listOf(r); }); }); }
  @override Widget build(BuildContext c) => Pad([
    const Eyebrow('Safety'), Text('Quiet, respectful, adult.', style: serif(34)), const SizedBox(height: 14),
    for (final s in ['City only. We never show or store exact GPS.', 'Your feed preferences are private and never appear on cards.', 'Block and report are always one tap away.', 'Declining or ignoring has no penalty.', kAgeNote])
      Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('•  $s')),
    const SizedBox(height: 18), SparkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Report or block someone you’ve matched with', style: serif(20)), const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: target, hint: const Text('Choose a person'), items: [for (final p in people) DropdownMenuItem(value: p['profileId'] as String, child: Text(p['displayName']))], onChanged: (v) => setState(() => target = v)),
      const SizedBox(height: 10), FilledButton(onPressed: target == null ? null : () => showReportDialog(c, targetId: target!), child: const Text('Continue')),
      const SizedBox(height: 6), const Text('You can also report from Discover cards and introductions.', style: TextStyle(fontSize: 12, color: C.muted))])),
  ]);
}
