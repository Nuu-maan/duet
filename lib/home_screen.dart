import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'appear.dart';
import 'art.dart';
import 'auth.dart';
import 'daily.dart';
import 'daily_screen.dart';
import 'games/games_screen.dart';
import 'inbox_screen.dart';
import 'lists_screen.dart';
import 'onboarding_screen.dart';
import 'pair.dart';
import 'play_card.dart';
import 'settings_screen.dart';
import 'streak_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Presence _presence;
  late Stream<DatabaseEvent> _members = membersRef().onValue;
  int _tab = 0;
  int _refreshes = 0;

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    setState(() {
      _members = membersRef().onValue;
      _refreshes++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _presence = Presence(widget.user);
  }

  @override
  void dispose() {
    _presence.stop();
    super.dispose();
  }

  Future<void> _signOut() async {
    await _presence.stop();
    await signOut();
  }

  void _open(WidgetBuilder builder) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _members,
      builder: (context, snapshot) {
        final error = snapshot.error;
        if (error != null) {
          final denied =
              error is FirebaseException && error.code == 'permission-denied';
          return Scaffold(
            body: SafeArea(
              child: MascotMessage(
                mascot: 'mascot_shocked',
                title: denied ? 'Not allowed' : 'Something went wrong',
                body: denied
                    ? '${widget.user.email ?? 'This account'} is not one of '
                          'the two people this app is for.'
                    : 'Could not reach the database.',
                actionLabel: denied ? 'Sign out' : 'Try again',
                onAction: denied
                    ? _signOut
                    : () => setState(() => _members = membersRef().onValue),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final uid = widget.user.uid;
        final members = parseMembers(snapshot.data!.snapshot.value, myUid: uid);
        if (members.where((m) => m.uid == uid).firstOrNull?.birthday == null) {
          return OnboardingScreen(user: widget.user);
        }
        final names = {for (final m in members) m.uid: m.name};
        void settings() => _open(
          (_) => SettingsScreen(
            uid: uid,
            email: widget.user.email ?? '',
            onSignOut: _signOut,
          ),
        );
        return Scaffold(
          body: SafeArea(
            child: switch (_tab) {
              0 => _HomeTab(
                members: members,
                uid: uid,
                refreshes: _refreshes,
                onRefresh: _refresh,
                onSettings: settings,
                onDaily: () =>
                    _open((_) => DailyScreen(uid: uid, names: names)),
              ),
              1 => InboxScreen(uid: uid, names: names, members: members),
              2 => GamesScreen(uid: uid, names: names),
              _ => _MoreTab(
                onBucket: () => _open((_) => BucketScreen(uid: uid)),
                onCountdowns: () => _open((_) => const CountdownsScreen()),
                onSettings: settings,
              ),
            },
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: 'Games',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline),
                selectedIcon: Icon(Icons.favorite),
                label: 'More',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.members,
    required this.uid,
    required this.onDaily,
    required this.onSettings,
    required this.refreshes,
    required this.onRefresh,
  });

  final List<Member> members;
  final String uid;
  final VoidCallback onDaily;
  final VoidCallback onSettings;
  final int refreshes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCard = theme.extension<Playful>()!.onCard;
    final paper = theme.extension<Playful>()!.paper;
    final friend = members.where((m) => m.uid != uid).firstOrNull;
    final toBirthday = daysToBirthday(friend?.birthday, DateTime.now());
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              for (final m in members)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: m.uid == uid
                      ? Tooltip(
                          message: 'Settings',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: onSettings,
                            child: MemberAvatar(member: m),
                          ),
                        )
                      : MemberAvatar(member: m),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  members.map((m) => m.name.split(' ').first).join(' & '),
                  style: theme.textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const _StreakChip(),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Today',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Appear(
            key: ValueKey(refreshes),
            child: PlayCard(
              onTap: onDaily,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const Art('mascot_hi', size: 112),
                  const SizedBox(height: 24),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: paper,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: onCard, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        "Answer today's $questionsPerDay questions",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: onCard,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: onCard,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Start challenge',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: paper,
                              ),
                            ),
                          ),
                          Icon(Icons.play_arrow_rounded, color: paper),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: friend == null
                  ? const Text(
                      'Waiting for your friend. '
                      'They will show up here once they sign in.',
                    )
                  : Row(
                      children: [
                        MemberAvatar(member: friend),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                presenceLabel(
                                  online: friend.online,
                                  lastSeen: friend.lastSeen,
                                  now: DateTime.now(),
                                ),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (toBirthday != null)
                                Text(
                                  toBirthday == 0
                                      ? '🎂 Birthday today!'
                                      : toBirthday == 1
                                      ? '🎂 Birthday tomorrow'
                                      : '🎂 Birthday in $toBirthday days',
                                  style: theme.textTheme.bodyMedium,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatefulWidget {
  const _StreakChip();

  @override
  State<_StreakChip> createState() => _StreakChipState();
}

class _StreakChipState extends State<_StreakChip> {
  final _events = streakRef().onValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playful = theme.extension<Playful>()!;
    return StreamBuilder<DatabaseEvent>(
      stream: _events,
      builder: (context, snapshot) {
        final streak = displayStreak(
          snapshot.data?.snapshot.value,
          dayKey(DateTime.now()),
        );
        return Semantics(
          button: true,
          label: '$streak day streak. Open streak calendar',
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StreakScreen()),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: playful.card(4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Art('fire', size: 24),
                    const SizedBox(width: 4),
                    ExcludeSemantics(
                      child: Text(
                        '$streak',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: playful.onCard,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.onBucket,
    required this.onCountdowns,
    required this.onSettings,
  });

  final VoidCallback onBucket;
  final VoidCallback onCountdowns;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onCard = theme.extension<Playful>()!.onCard;
    Widget tile(int color, IconData icon, String title, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: PlayCard(
            colorIndex: color,
            onTap: onTap,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(color: onCard),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('More', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        tile(1, Icons.checklist_rounded, 'Bucket list', onBucket),
        tile(3, Icons.event_rounded, 'Countdowns', onCountdowns),
        tile(2, Icons.settings_rounded, 'Settings', onSettings),
      ],
    );
  }
}
