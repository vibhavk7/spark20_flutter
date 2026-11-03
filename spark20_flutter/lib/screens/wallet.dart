import 'package:flutter/material.dart';
import '../core.dart';

class WalletScreen extends StatefulWidget { const WalletScreen({super.key}); @override State<WalletScreen> createState() => _S(); }
class _S extends State<WalletScreen> {
  List<Map<String, dynamic>> rows = [];
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    final r = await guard(context, () => sb.from('spark20_ledger_entries').select().order('created_at', ascending: false));
    if (mounted && r != null) setState(() => rows = listOf(r));
  }
  int sum(bool Function(Map) f) => rows.where(f).fold<int>(0, (a, e) => a + (e['amount_paise'] as int));
  static const names = {'intro_charge': 'Introduction payment', 'reward_pending': 'Reply reward (pending)', 'reward_pending_reversed': 'Reward reversed (pending)',
    'reward_available': 'Reward available', 'reward_reversed': 'Reward reversed', 'reward_disputed': 'Reward disputed'};
  Widget bal(String l, int v) => SparkCard(pad: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: C.muted, fontSize: 12)), Text(inr(v), style: serif(24))]));
  @override Widget build(BuildContext c) {
    final pending = sum((e) => e['kind'] == 'reward_pending' && e['status'] == 'pending');
    final avail = sum((e) => e['kind'] == 'reward_available');
    final rev = sum((e) => e['kind'] == 'reward_pending_reversed' || e['kind'] == 'reward_reversed');
    final disp = sum((e) => e['kind'] == 'reward_disputed');
    final minimum = app.minimumWithdrawalPaise;
    return Pad([
      const Eyebrow('Wallet'), Text('A simple ledger.', style: serif(34)), const SizedBox(height: 12),
      Wrap(spacing: 10, children: [for (final b in [('Pending', pending), ('Available', avail), ('Minimum to withdraw', minimum), ('Reversed', rev), ('Disputed', disp)]) SizedBox(width: 160, child: bal(b.$1, b.$2))]),
      Text(avail >= minimum ? 'Minimum balance reached. Withdrawals are not available until payout setup is complete.' : 'Withdrawals require ${inr(minimum)} in available rewards and remain disabled until payout setup is complete.', style: const TextStyle(color: C.muted, fontSize: 12)),
      const SizedBox(height: 8),
      const SparkCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Payment costs (estimate)', style: TextStyle(fontWeight: FontWeight.w700)),
        SizedBox(height: 4),
        Text('Razorpay web estimate: about ₹0.48 processing fee on a ₹20.49 payment (2% + GST on the fee). Actual settlement fees are not recorded yet because live payments are not connected. Google Play fees vary by account and current Play terms.', style: TextStyle(color: C.muted, fontSize: 12)),
      ])),
      const FilledButton(onPressed: null, child: Text('Withdrawals not available yet')),
      const SizedBox(height: 16), Text('Activity', style: serif(22)), const SizedBox(height: 8),
      if (rows.isEmpty) const Text('Nothing here yet. That’s fine.', style: TextStyle(color: C.muted)),
      for (final e in rows) SparkCard(pad: const EdgeInsets.all(14), child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(names[e['kind']] ?? e['kind']), Text('${when(e['created_at'])} · ${e['status']}', style: const TextStyle(fontSize: 12, color: C.muted))])),
        Text(inr(e['amount_paise'] as int), style: const TextStyle(fontWeight: FontWeight.w700))])),
    ]);
  }
}
