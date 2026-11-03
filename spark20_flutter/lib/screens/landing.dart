import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});
  @override Widget build(BuildContext c) {
    const props = [
      ('Mutual means mutual', 'Likes become matches only when both people like. Chat after a match is always free.'),
      ('Your pace is the right pace', 'Declining or ignoring has no penalty. A profile is never a promise to respond.'),
      ('Clarity, not clever tricks', 'Direct introductions will be available after secure payment providers are configured.'),
    ];
    return Scaffold(body: SingleChildScrollView(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 960), child: Padding(
      padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text('Spark20', style: serif(28, w: FontWeight.w600)), const Spacer(),
          TextButton(onPressed: () => c.go('/sign-in'), child: const Text('Sign in'))]),
        const SizedBox(height: 40),
        const Eyebrow('India-first · 18+ · unhurried'),
        const SizedBox(height: 12),
        RichText(text: TextSpan(style: serif(54), children: [
          const TextSpan(text: 'Let a little '), TextSpan(text: 'something', style: serif(54, color: C.green, style: FontStyle.italic)), const TextSpan(text: ' begin.')])),
        const SizedBox(height: 14),
        Text('A little intention goes a long way.', style: GoogleFonts2.body(18)),
        const SizedBox(height: 22),
        Row(children: [FilledButton(onPressed: () => c.go('/sign-up'), child: const Text('Make room for a spark')), const SizedBox(width: 12),
          OutlinedButton(onPressed: () => c.go('/sign-in'), child: const Text('Welcome back'))]),
        const SizedBox(height: 32), const _Hero(), const SizedBox(height: 32),
        for (var i = 0; i < props.length; i++) Padding(padding: const EdgeInsets.only(bottom: 18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${i + 1}', style: serif(34, color: C.green)), const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(props[i].$1, style: serif(22)), const SizedBox(height: 4), Text(props[i].$2, style: const TextStyle(color: C.muted, height: 1.4))]))])),
        Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: C.sage, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Eyebrow('Safety commitments'), const SizedBox(height: 10),
            for (final s in ['Precise location is optional, private, and used only for radius filtering.', 'Your preferences stay private.', 'Block and report are always available.', 'Adults 18+ only (self-confirmed).'])
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('•  $s'))])),
        const SizedBox(height: 28),
        Center(child: Text('Made for real connection, in India.', style: serif(16, style: FontStyle.italic, color: C.muted))),
        const SizedBox(height: 20),
      ]))))));
  }
}
class GoogleFonts2 { static TextStyle body(double s) => TextStyle(fontSize: s, color: C.muted); }

class _Hero extends StatelessWidget {
  const _Hero();
  @override Widget build(BuildContext c) => Container(height: 240, width: double.infinity, decoration: BoxDecoration(color: C.sage, borderRadius: BorderRadius.circular(28)),
    child: Stack(alignment: Alignment.bottomCenter, children: [
      Positioned(top: 30, right: 80, child: Container(width: 70, height: 70, decoration: const BoxDecoration(color: C.sun, shape: BoxShape.circle))),
      Container(width: 220, height: 190, decoration: BoxDecoration(border: Border.all(color: C.leaf, width: 3), borderRadius: const BorderRadius.vertical(top: Radius.circular(110)))),
      Positioned(bottom: 0, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 56, height: 120, decoration: BoxDecoration(color: C.terracotta, borderRadius: BorderRadius.circular(28))), const SizedBox(width: 10),
        Container(width: 56, height: 140, decoration: BoxDecoration(color: C.leaf, borderRadius: BorderRadius.circular(28)))])),
      const Positioned(top: 40, left: 40, child: Icon(Icons.auto_awesome, color: C.terracotta, size: 28)),
    ]));
}

class AuthScreen extends StatefulWidget {
  final bool signUp; const AuthScreen({super.key, required this.signUp});
  @override State<AuthScreen> createState() => _AuthState();
}
class _AuthState extends State<AuthScreen> {
  final email = TextEditingController(), pass = TextEditingController(); bool busy = false; String? note;
  Future<void> go() async {
    setState(() { busy = true; note = null; });
    try {
      if (widget.signUp) {
        final r = await sb.auth.signUp(email: email.text.trim(), password: pass.text);
        if (r.session == null) note = 'Check your email to confirm your address, then sign in.';
      } else {
        await sb.auth.signInWithPassword(email: email.text.trim(), password: pass.text);
      }
    } on AuthException catch (e) { note = e.message; } catch (e) { note = e.toString(); }
    if (mounted) setState(() => busy = false);
  }
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(backgroundColor: C.cream, leading: BackButton(onPressed: () => c.go('/'))),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Padding(padding: const EdgeInsets.all(24), child: SparkCard(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(widget.signUp ? 'Make room for a spark' : 'Welcome back', style: serif(30)), const SizedBox(height: 16),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')), const SizedBox(height: 10),
      TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password (min 6)')), const SizedBox(height: 14),
      if (note != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(note!, style: const TextStyle(color: C.danger))),
      SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : go, child: Text(widget.signUp ? 'Create account' : 'Sign in'))),
      const SizedBox(height: 10), const Text(kAgeNote, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: C.muted)),
      TextButton(onPressed: () => c.go(widget.signUp ? '/sign-in' : '/sign-up'), child: Text(widget.signUp ? 'I already have an account' : 'Create an account')),
    ]))))));
}
