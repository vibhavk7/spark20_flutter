import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core.dart';
import 'safety.dart';

class MatchesScreen extends StatefulWidget { const MatchesScreen({super.key}); @override State<MatchesScreen> createState() => _S(); }
class _S extends State<MatchesScreen> {
  List<Map<String, dynamic>> items = []; bool loading = true;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async { final r = await guard(context, () => sb.rpc('s20_matches')); if (mounted) setState(() { items = listOf(r); loading = false; }); }
  @override Widget build(BuildContext c) => Pad([
    const Eyebrow('Matches'), Text('Mutual, both ways.', style: serif(34)), const SizedBox(height: 12),
    if (loading) const Center(child: CircularProgressIndicator())
    else if (items.isEmpty) const Text('No matches yet. That’s completely fine.', style: TextStyle(color: C.muted)),
    for (final m in items) SparkCard(pad: const EdgeInsets.all(12), child: ListTile(
      onTap: () async { await c.push('/matches/${m['matchId']}'); load(); },
      leading: Avatar(m['displayName'], url: m['photoUrl'], size: 52),
      title: Text('${m['displayName']}, ${m['age']}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(m['lastMessage'] ?? 'Say hello. Chat is free.', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: (m['unread'] as int) > 0 ? CircleAvatar(radius: 12, backgroundColor: C.green, child: Text('${m['unread']}', style: const TextStyle(color: Colors.white, fontSize: 12))) : null)),
  ]);
}

class ChatScreen extends StatefulWidget { final String matchId; const ChatScreen({super.key, required this.matchId}); @override State<ChatScreen> createState() => _C(); }
class _C extends State<ChatScreen> {
  Map<String, dynamic>? data; Timer? t; final input = TextEditingController(); final sc = ScrollController(); int lastCount = -1;
  @override void initState() { super.initState(); load(); t = Timer.periodic(const Duration(seconds: 5), (_) => load()); }
  @override void dispose() { t?.cancel(); super.dispose(); }
  Future<void> load() async {
    try {
      final r = await sb.rpc('s20_get_messages', params: {'p_match': widget.matchId});
      if (!mounted) return;
      final d = Map<String, dynamic>.from(r as Map);
      setState(() => data = d);
      final n = (d['messages'] as List).length;
      if (n != lastCount) { lastCount = n; WidgetsBinding.instance.addPostFrameCallback((_) { if (sc.hasClients) sc.jumpTo(sc.position.maxScrollExtent); }); }
    } catch (_) { if (mounted && data == null) context.go('/matches'); }
  }
  Future<void> send() async {
    final txt = input.text.trim(); if (txt.isEmpty) return;
    input.clear();
    await guard(context, () => sb.rpc('s20_send_message', params: {'p_match': widget.matchId, 'p_content': txt}));
    load();
  }
  @override Widget build(BuildContext c) {
    final d = data; if (d == null) return const Center(child: CircularProgressIndicator());
    final other = Map<String, dynamic>.from(d['other']); final msgs = listOf(d['messages']); final me = d['me'];
    return Column(children: [
      ListTile(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => c.go('/matches')),
        title: Row(children: [Avatar(other['displayName'], url: other['photoUrl'], size: 36), const SizedBox(width: 10), Text(other['displayName'], style: serif(22))]),
        trailing: PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'unmatch') { await guard(c, () => sb.rpc('s20_unmatch', params: {'p_match': widget.matchId})); load(); }
          else { showReportDialog(c, targetId: other['id'], name: other['displayName']); }
        }, itemBuilder: (_) => const [PopupMenuItem(value: 'unmatch', child: Text('Unmatch')), PopupMenuItem(value: 'report', child: Text('Report or block'))])),
      Expanded(child: msgs.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text('A fresh beginning.', style: serif(26)), const SizedBox(height: 6), const Text('A warm hello can be enough.', style: TextStyle(color: C.muted))]))
        : ListView(controller: sc, padding: const EdgeInsets.all(16), children: [for (final m in msgs) Align(
            alignment: m['senderId'] == me ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), constraints: const BoxConstraints(maxWidth: 520),
              decoration: BoxDecoration(color: m['senderId'] == me ? C.green : C.sand, borderRadius: BorderRadius.circular(18)),
              child: Text(m['content'], style: TextStyle(color: m['senderId'] == me ? Colors.white : C.forest))))])),
      if (d['active'] != true) const Padding(padding: EdgeInsets.all(14), child: Text('This match has ended. No more messages.', style: TextStyle(color: C.muted)))
      else Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(controller: input, maxLength: 2000, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Say something kind', counterText: ''))), const SizedBox(width: 8),
        FilledButton(key: const Key('chat-send'), onPressed: send, child: const Icon(Icons.send, size: 18))])),
    ]);
  }
}
