import 'package:flutter/material.dart';
import '../core.dart';
import 'safety.dart';

class IntrosScreen extends StatefulWidget { const IntrosScreen({super.key}); @override State<IntrosScreen> createState() => _S(); }
class _S extends State<IntrosScreen> {
  List<Map<String, dynamic>> items = []; bool received = true, loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { final r = await guard(context, () => sb.rpc('s20_intros')); if (mounted) setState(() { items = listOf(r); loading = false; }); }
  @override Widget build(BuildContext c) {
    final list = items.where((i) => (i['direction'] == 'received') == received).toList();
    return Pad([
      const Eyebrow('Introductions'), Text('Optional, never an obligation.', style: serif(34)), const SizedBox(height: 10),
      Row(children: [SparkChip('Received', selected: received, onTap: () => setState(() => received = true)), const SizedBox(width: 8), SparkChip('Sent', selected: !received, onTap: () => setState(() => received = false)), const Spacer(),
        const FilledButton(key: Key('intro-new'), onPressed: null, child: Text('New introduction'))]),
      const Padding(padding: EdgeInsets.only(top: 8), child: Text('Sending is paused until verified Play Billing and Razorpay payments are configured.', style: TextStyle(color: C.muted))),
      const SizedBox(height: 14),
      if (loading) const Center(child: CircularProgressIndicator()) else if (list.isEmpty) const Text('Nothing here yet. No rush.', style: TextStyle(color: C.muted)),
      for (final i in list) IntroTile(key: ValueKey(i['id']), i: i, onChanged: load),
    ]);
  }
}

class IntroTile extends StatefulWidget { final Map<String, dynamic> i; final VoidCallback onChanged; const IntroTile({super.key, required this.i, required this.onChanged}); @override State<IntroTile> createState() => _T(); }
class _T extends State<IntroTile> {
  final reply = TextEditingController();
  Map<String, dynamic> get i => widget.i;
  Future<void> rpc(String fn, Map<String, dynamic> p, [String? ok]) async {
    final r = await guard(context, () => sb.rpc(fn, params: p)); // ignore: unused_local_variable
    if (mounted && ok != null) toast(context, ok);
    widget.onChanged();
  }
  @override Widget build(BuildContext c) {
    final sent = i['direction'] == 'sent'; final st = i['status'] as String; final id = i['id'];
    final replies = listOf(i['replies']);
    final canReply = ['accepted', 'replied'].contains(st);
    return SparkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Avatar(i['otherName'], url: i['otherPhoto'], size: 40), const SizedBox(width: 10),
        Expanded(child: Text('${sent ? 'To' : 'From'} ${i['otherName']}', style: const TextStyle(fontWeight: FontWeight.w700))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: C.sand, borderRadius: BorderRadius.circular(99)), child: Text(st.replaceAll('_', ' '), style: const TextStyle(fontSize: 12)))]),
      const SizedBox(height: 10), Text(i['content'], style: const TextStyle(height: 1.4)),
      Text('${inr(i['pricePaise'])} · ${when(i['createdAt'])}', style: const TextStyle(fontSize: 11, color: C.muted)),
      if (!sent && st == 'paid') ...[const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 4, children: [
        FilledButton(key: const Key('intro-accept'), onPressed: () => rpc('s20_decision', {'p_intro': id, 'p_decision': 'accept'}), child: const Text('Accept')),
        OutlinedButton(onPressed: () => rpc('s20_decision', {'p_intro': id, 'p_decision': 'decline'}), child: const Text('Decline')),
        OutlinedButton(onPressed: () => rpc('s20_decision', {'p_intro': id, 'p_decision': 'ignore'}), child: const Text('Ignore')),
        TextButton(onPressed: () async { await rpc('s20_decision', {'p_intro': id, 'p_decision': 'block'}, 'Blocked.'); }, child: const Text('Block', style: TextStyle(color: C.danger))),
        TextButton(onPressed: () async { await showReportDialog(c, targetId: i['otherId'], name: i['otherName'], introId: id); widget.onChanged(); }, child: const Text('Report'))]),
        const Text('Declining or ignoring has no penalty.', style: TextStyle(fontSize: 11, color: C.muted))],
      for (final r in replies) Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: r['mine'] == true ? C.sage : C.sand, borderRadius: BorderRadius.circular(14)), child: Text('${r['mine'] == true ? 'You' : i['otherName']}: ${r['content']}')),
      if (canReply) ...[const SizedBox(height: 10),
        TextField(controller: reply, maxLength: 1000, maxLines: 2, decoration: const InputDecoration(hintText: 'Reply (optional)')),
        Text('When the recipient replies after accepting, both people receive ${inr(app.reward)} in pending rewards. Cash-out requires at least ${inr(app.minimumWithdrawalPaise)} and is not enabled yet.', style: const TextStyle(fontSize: 11, color: C.muted)),
        Align(alignment: Alignment.centerRight, child: FilledButton(key: const Key('intro-reply'), onPressed: () async { final t = reply.text; reply.clear(); await rpc('s20_reply', {'p_intro': id, 'p_content': t}); }, child: const Text('Send reply')))],
    ]));
  }
}
