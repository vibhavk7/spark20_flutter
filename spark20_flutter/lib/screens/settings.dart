import 'dart:convert';
import 'package:flutter/material.dart';
import '../core.dart';
import 'profile.dart' show storagePath;

class SettingsScreen extends StatefulWidget { const SettingsScreen({super.key}); @override State<SettingsScreen> createState() => _S(); }
class _S extends State<SettingsScreen> {
  late bool visible; late RangeValues ages, heights; late Set<String> feed;
  @override void initState() {
    super.initState();
    final p = app.profile;
    visible = p?['visible'] ?? true; feed = Set<String>.from(p?['show_in_feed_genders'] ?? <String>[]);
    ages = RangeValues(((p?['min_age_preference'] ?? 18) as int).toDouble(), ((p?['max_age_preference'] ?? 45) as int).toDouble());
    heights = RangeValues(((p?['min_height_preference_cm'] ?? 100) as int).toDouble(), ((p?['max_height_preference_cm'] ?? 250) as int).toDouble());
  }
  void toggleFeed(String k) => setState(() {
    if (k == 'everyone') { feed = feed.contains('everyone') ? {} : {'everyone'}; }
    else { feed.remove('everyone'); feed.contains(k) ? feed.remove(k) : feed.add(k); }
  });
  Future<void> save() async {
    if (feed.isEmpty) { toast(context, 'Choose at least one option for your feed.'); return; }
    final ok = await guard(context, () async { await sb.from('spark20_profiles').update({'visible': visible, 'min_age_preference': ages.start.round(), 'max_age_preference': ages.end.round(), 'min_height_preference_cm': heights.start.round(), 'max_height_preference_cm': heights.end.round(), 'show_in_feed_genders': feed.toList()}).eq('user_id', sb.auth.currentUser!.id); return true; });
    if (ok == true) { await app.load(); if (mounted) toast(context, 'Settings saved.'); }
  }
  Future<void> export() async {
    final r = await guard(context, () => sb.rpc('s20_export')); if (r == null || !mounted) return;
    final txt = const JsonEncoder.withIndent('  ').convert(r);
    showDialog(context: context, builder: (dc) => AlertDialog(title: const Text('Your data (JSON)'), content: SizedBox(width: 500, height: 400, child: SingleChildScrollView(child: SelectableText(txt, style: const TextStyle(fontSize: 11)))),
      actions: [TextButton(onPressed: () => copy(context, txt), child: const Text('Copy')), TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Close'))]));
  }
  Future<void> delete() async {
    final ok = await showDialog<bool>(context: context, builder: (dc) => AlertDialog(title: const Text('Delete your account?'), content: const Text('This removes your profile, matches, messages and photos. Financial ledger history is retained as required for accounting, unlinked from you.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Keep it')), TextButton(onPressed: () => Navigator.pop(dc, true), child: const Text('Delete', style: TextStyle(color: C.danger)))]));
    if (ok != true || !mounted) return;
    try {
      final u = sb.auth.currentUser!.id;
      final files = await sb.storage.from('photos').list(path: u);
      if (files.isNotEmpty) await sb.storage.from('photos').remove(files.map((f) => '$u/${f.name}').toList());
      await sb.rpc('s20_delete_account');
      await sb.auth.signOut();
    } catch (e) { if (mounted) toast(context, errText(e)); }
  }
  @override Widget build(BuildContext c) => Pad([
    const Eyebrow('Settings'), Text('Your pace.', style: serif(34)),
    SwitchListTile(value: visible, onChanged: (v) => setState(() => visible = v), contentPadding: EdgeInsets.zero, activeColor: C.green, title: const Text('Show me in discovery'), subtitle: const Text('Turn off to pause without deleting anything.')),
    const SizedBox(height: 10), const Eyebrow('Who should appear in my feed'), const SizedBox(height: 8),
    Wrap(spacing: 8, runSpacing: 8, children: [for (final f in kFeed) SparkChip(f.$2, selected: feed.contains(f.$1), onTap: () => toggleFeed(f.$1))]),
    const SizedBox(height: 22), const Eyebrow('Age preference'), const SizedBox(height: 6), AgeRangeField(ages, (v) => setState(() => ages = v)),
    const SizedBox(height: 22), const Eyebrow('Height preference'), const SizedBox(height: 6), HeightRangeField(heights, (v) => setState(() => heights = v)),
    const SizedBox(height: 10), FilledButton(key: const Key('save-settings'), onPressed: save, child: const Text('Save settings')),
    const Divider(height: 40),
    Text('Your data', style: serif(22)), const SizedBox(height: 8),
    Wrap(spacing: 10, children: [OutlinedButton(onPressed: export, child: const Text('Export my data')), OutlinedButton(onPressed: delete, child: const Text('Delete account', style: TextStyle(color: C.danger)))]),
  ]);
}
