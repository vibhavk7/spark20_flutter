import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core.dart';
import 'screens/landing.dart';
import 'screens/home.dart';
import 'screens/discover.dart';
import 'screens/matches.dart';
import 'screens/intros.dart';
import 'screens/wallet.dart';
import 'screens/profile.dart';
import 'screens/settings.dart';
import 'screens/safety.dart';
import 'screens/admin.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isEmpty || supabaseAnon.isEmpty) {
    runApp(MaterialApp(theme: buildTheme(), home: const Scaffold(body: Center(child: Padding(padding: EdgeInsets.all(24),
      child: Text('Setup needed: run with --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...'))))));
    return;
  }
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnon);
  sb.auth.onAuthStateChange.listen((_) => app.load());
  app.load();
  runApp(const SparkApp());
}

const _pub = ['/', '/sign-in', '/sign-up'];
const _gated = ['/home', '/discover', '/matches', '/introductions', '/wallet'];

final router = GoRouter(
  refreshListenable: app,
  redirect: (ctx, st) {
    final loc = st.matchedLocation;
    final signedIn = sb.auth.currentSession != null;
    if (!signedIn) return _pub.contains(loc) ? null : '/';
    if (!app.loaded) return null;
    if (_pub.contains(loc)) return app.profile == null ? '/profile' : '/discover';
    if (app.profile == null && (_gated.contains(loc) || loc.startsWith('/matches/'))) return '/profile';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
    GoRoute(path: '/sign-in', builder: (_, __) => const AuthScreen(signUp: false)),
    GoRoute(path: '/sign-up', builder: (_, __) => const AuthScreen(signUp: true)),
    ShellRoute(
      builder: (c, s, child) => Shell(loc: s.matchedLocation, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen()),
        GoRoute(path: '/matches', builder: (_, __) => const MatchesScreen()),
        GoRoute(path: '/matches/:id', builder: (_, s) => ChatScreen(matchId: s.pathParameters['id']!)),
        GoRoute(path: '/introductions', builder: (_, __) => const IntrosScreen()),
        GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(path: '/safety', builder: (_, __) => const SafetyScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
      ],
    ),
  ],
);

class SparkApp extends StatelessWidget {
  const SparkApp({super.key});
  @override Widget build(BuildContext c) => MaterialApp.router(title: 'Spark20', theme: buildTheme(), routerConfig: router, debugShowCheckedModeBanner: false);
}

class Shell extends StatelessWidget {
  final String loc; final Widget child;
  const Shell({super.key, required this.loc, required this.child});
  static const tabs = [
    ('/discover', 'Discover', Icons.favorite_border), ('/matches', 'Matches', Icons.chat_bubble_outline),
    ('/introductions', 'Introductions', Icons.mail_outline), ('/wallet', 'Wallet', Icons.account_balance_wallet_outlined),
  ];
  @override Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 760;
    final idx = tabs.indexWhere((t) => loc.startsWith(t.$1));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: C.cream, elevation: 0, scrolledUnderElevation: 0,
        title: InkWell(onTap: () => context.go('/home'), child: Text('Spark20', style: serif(26, w: FontWeight.w600))),
        actions: [
          if (wide) for (final t in tabs) TextButton(onPressed: () => context.go(t.$1), child: Text(t.$2, style: TextStyle(fontWeight: loc.startsWith(t.$1) ? FontWeight.w800 : FontWeight.w500))),
          PopupMenuButton<String>(icon: const Icon(Icons.menu), onSelected: (v) => context.go(v), itemBuilder: (_) => [
            const PopupMenuItem(value: '/home', child: Text('Home')),
            const PopupMenuItem(value: '/profile', child: Text('Profile')),
            const PopupMenuItem(value: '/safety', child: Text('Safety')),
            if (app.isAdmin) const PopupMenuItem(value: '/admin', child: Text('Admin')),
          ]),
          IconButton(tooltip: 'Settings', icon: const Icon(Icons.settings_outlined), onPressed: () => context.go('/settings')),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: () => sb.auth.signOut()),
        ],
      ),
      bottomNavigationBar: (!wide && idx >= 0)
          ? NavigationBar(selectedIndex: idx, backgroundColor: C.cream, indicatorColor: C.sage,
              onDestinationSelected: (i) => context.go(tabs[i].$1),
              destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.$3), label: t.$2)])
          : null,
      body: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(loc), tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 300),
          builder: (c, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 10), child: ch)),
          child: child))),
    );
  }
}
