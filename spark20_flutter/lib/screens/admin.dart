import 'package:flutter/material.dart';
import '../core.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});
  @override Widget build(BuildContext c) {
    if (!app.isAdmin) return Pad([const Eyebrow('Admin'), Text('Moderators only.', style: serif(30)), const SizedBox(height: 8), const Text('Your account isn’t in spark20_admins.', style: TextStyle(color: C.muted))]);
    return DefaultTabController(length: 3, child: Column(children: [
      const TabBar(isScrollable: true, labelColor: C.green, indicatorColor: C.green, tabs: [Tab(text: 'Reports'), Tab(text: 'Rewards'), Tab(text: 'Settings')]),
      Expanded(child: TabBarView(children: [
        _Feed('s20_admin_reports', 'No open reports.', (m, r) => [
          Text('${m['category']} · ${m['reporter']} → ${m['target']}', style: const TextStyle(fontWeight: FontWeight.w700)), Text(m['details'] ?? ''), Text('${m['status']} · ${when(m['createdAt'])}', style: const TextStyle(fontSize: 12, color: C.muted)),
          Wrap(spacing: 8, children: [
            OutlinedButton(key: const Key('admin-dismiss'), onPressed: () => _do(c, 's20_admin_review_report', {'p_id': m['id'], 'p_status': 'dismissed'}, r), child: const Text('Dismiss')),
            FilledButton(key: const Key('admin-action'), onPressed: () => _do(c, 's20_admin_review_report', {'p_id': m['id'], 'p_status': 'actioned'}, r), child: const Text('Suspend target')),
            OutlinedButton(onPressed: () => _do(c, 's20_admin_review_report', {'p_id': m['id'], 'p_status': 'needs_followup'}, r), child: const Text('Needs follow-up'))])]),
        _Feed('s20_admin_rewards', 'No rewards past the pending window.', (m, r) => [
          Text('${m['profile'] ?? 'Deleted user'} · ${inr(m['amountPaise'])} reward', style: const TextStyle(fontWeight: FontWeight.w700)), Text(when(m['createdAt']), style: const TextStyle(fontSize: 12, color: C.muted)),
          Wrap(spacing: 8, children: [for (final d in ['approve', 'reverse', 'dispute']) OutlinedButton(key: Key('admin-reward-$d'), onPressed: () => _do(c, 's20_admin_reward_decide', {'p_id': m['id'], 'p_decision': d}, r), child: Text(d))])]),
        const _AdminSettings(),
      ])),
    ]));
  }
  static Future<void> _do(BuildContext c, String fn, Map<String, dynamic> p, VoidCallback reload) async { await guard(c, () => sb.rpc(fn, params: p)); reload(); }
}

class _Feed extends StatefulWidget {
  final String fn, empty; final List<Widget> Function(Map<String, dynamic>, VoidCallback) tile;
  const _Feed(this.fn, this.empty, this.tile);
  @override State<_Feed> createState() => _FS();
}
class _FS extends State<_Feed> {
  List<Map<String, dynamic>> items = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { final r = await guard(context, () => sb.rpc(widget.fn)); if (mounted) setState(() => items = listOf(r)); }
  @override Widget build(BuildContext c) => Pad([if (items.isEmpty) Text(widget.empty, style: const TextStyle(color: C.muted)),
    for (final m in items) SparkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final w in widget.tile(m, load)) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: w)]))]);
}

class _AdminSettings extends StatefulWidget { const _AdminSettings(); @override State<_AdminSettings> createState() => _AS(); }
class _AS extends State<_AdminSettings> {
  late final days = TextEditingController(text: '${app.config?['reward_pending_days'] ?? 7}');
  Widget f(String l, TextEditingController t) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: t, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l)));
  @override Widget build(BuildContext c) => Pad([
    Text('Business settings', style: serif(24)), const SizedBox(height: 4), const Text('Live payments and payouts are disabled until provider verification and server-side payment processing are configured. The withdrawal minimum is ₹100.', style: TextStyle(color: C.muted, fontSize: 12)), const SizedBox(height: 12),
    f('Reward pending days', days),
    FilledButton(onPressed: () async {
      final r = await guard(c, () => sb.rpc('s20_admin_update_settings', params: {'p_price': 2049, 'p_reward': 500, 'p_min': 1, 'p_days': int.parse(days.text), 'p_enabled': true}));
      await app.load(); if (c.mounted && r == null) toast(c, 'Saved.'); }, child: const Text('Save business settings')),
  ]);
}
