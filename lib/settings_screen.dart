import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'daily.dart';
import 'lists_screen.dart';
import 'notifications.dart';
import 'pair.dart';

// The photo lives in the Realtime Database as base64 because the free plan
// has no file storage, so it must stay small.
const _maxPhotoBytes = 60 * 1024;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.onSignOut,
    this.friendUid,
    this.friendName,
  });

  final String uid;
  final String email;
  final String? friendUid;
  final String? friendName;
  final VoidCallback onSignOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _me = membersRef().child(widget.uid);
  late final _events = _me.onValue;
  bool _busy = false;

  Future<void> _save(Map<String, Object?> change) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _me.update(change);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save.')));
    }
  }

  Future<void> _changePhoto(ImageSource source) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        messenger.showSnackBar(
          const SnackBar(content: Text('That photo is too big. Try another.')),
        );
        return;
      }
      await _save({'photo': base64Encode(bytes)});
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the photo.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _photoSheet(bool hasPhoto) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheet);
                _changePhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheet);
                _changePhoto(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () {
                  Navigator.pop(sheet);
                  _save({'photo': null});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeName(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) await _save({'name': name});
  }

  Future<void> _changeBirthday(String? current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current ?? '') ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (date != null) await _save({'birthday': dayKey(date)});
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('Your answers, games and lists stay saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: StreamBuilder<DatabaseEvent>(
          stream: _events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Could not load your profile.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final me = parseMembers({
              widget.uid: snapshot.data!.snapshot.value,
            }, myUid: widget.uid).firstOrNull;
            if (me == null) {
              return const Center(child: Text('Could not load your profile.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      MemberAvatar(member: me, radius: 56, showOnline: false),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: IconButton.filled(
                          tooltip: 'Change photo',
                          onPressed: _busy
                              ? null
                              : () => _photoSheet(me.photo != null),
                          icon: _busy
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.photo_camera),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  me.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Change name'),
                        subtitle: Text(me.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _changeName(me.name),
                      ),
                      ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const Text('Birthday'),
                        subtitle: Text(me.birthday ?? 'Not set'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _changeBirthday(me.birthday),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_camera_outlined),
                        title: const Text('Profile photo'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy
                            ? null
                            : () => _photoSheet(me.photo != null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      _NotificationSwitches(uid: widget.uid),
                      if (widget.friendUid != null)
                        ListTile(
                          leading: const Icon(
                            Icons.edit_notifications_outlined,
                          ),
                          title: Text('Nudges for ${widget.friendName}'),
                          subtitle: const Text(
                            'Write your own streak reminders for them',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => NudgesScreen(
                                friendUid: widget.friendUid!,
                                friendName: widget.friendName ?? 'your friend',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Account',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(Icons.logout, color: scheme.error),
                    title: Text(
                      'Sign out',
                      style: TextStyle(color: scheme.error),
                    ),
                    onTap: _signOut,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationSwitches extends StatefulWidget {
  const _NotificationSwitches({required this.uid});

  final String uid;

  @override
  State<_NotificationSwitches> createState() => _NotificationSwitchesState();
}

class _NotificationSwitchesState extends State<_NotificationSwitches> {
  late final _device = deviceRef(widget.uid);
  late final _events = _device.onValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: _events,
      builder: (context, snapshot) {
        final value = snapshot.data?.snapshot.value;
        final device = value is Map ? value : const {};
        return Column(
          children: [
            for (final (key, title, subtitle) in const [
              ('streak', 'Streak reminders', 'Daily nudge and streak warnings'),
              ('friend', 'Friend activity', 'Answers, messages, birthdays'),
              ('games', 'Games', 'When it is your turn'),
            ])
              SwitchListTile(
                title: Text(title),
                subtitle: Text(subtitle),
                value: device[key] != false,
                onChanged: snapshot.hasData
                    ? (on) => _device.update({key: on}).catchError((_) {})
                    : null,
              ),
          ],
        );
      },
    );
  }
}
