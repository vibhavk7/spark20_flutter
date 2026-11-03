import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core.dart';

class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _S(); }
class _S extends State<HomeScreen> {
  Map<String, dynamic> s = {};
  @override void initState() { super.initState(); guard(context, () async { final r = await sb.rpc('s20_home_summary'); if (mounted) setState(() => s = Map<String, dynamic>.from(r as Map)); }); }
  Widget stat(String l, dynamic v) => Expanded(child: SparkCard(child: Column(children: [Text('${v ?? 0}', style: serif(34, color: C.green)), Text(l, style: const TextStyle(color: C.muted))])));
  @override Widget build(BuildContext c) => Pad([
    const Eyebrow('Home'), const SizedBox(height: 6),
    Text('Welcome, ${app.profile?['display_name'] ?? ''}.', style: serif(36)), const SizedBox(height: 16),
    Row(children: [stat('Matches', s['matches']), const SizedBox(width: 10), stat('Unread', s['unread']), const SizedBox(width: 10), stat('Intros', s['intros'])]),
    Wrap(spacing: 10, children: [FilledButton(onPressed: () => c.go('/discover'), child: const Text('Open Discover')), OutlinedButton(onPressed: () => c.go('/profile'), child: const Text('Edit profile'))]),
  ]);
}
