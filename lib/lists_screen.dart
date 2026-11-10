import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import 'art.dart';
import 'daily.dart';
import 'lists.dart';

typedef _Entry = MapEntry<String, Map<Object?, Object?>>;

class _EntryList extends StatelessWidget {
  const _EntryList({
    required this.events,
    required this.emptyText,
    required this.itemBuilder,
    this.sort,
  });

  final Stream<DatabaseEvent> events;
  final String emptyText;
  final Widget Function(BuildContext context, _Entry entry) itemBuilder;
  final Comparator<_Entry>? sort;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: events,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const MascotMessage(
            mascot: 'mascot_shocked',
            title: 'Could not load',
            body: 'Check your connection.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = entriesOf(snapshot.data!.snapshot.value);
        if (sort != null) entries.sort(sort);
        if (entries.isEmpty) return MascotMessage(title: emptyText);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: entries.length,
          itemBuilder: (context, i) => itemBuilder(context, entries[i]),
        );
      },
    );
  }
}

void Function(Object) _saveFailed(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  return (_) =>
      messenger.showSnackBar(const SnackBar(content: Text('Could not save.')));
}

class BucketScreen extends StatefulWidget {
  const BucketScreen({super.key, required this.uid});

  final String uid;

  @override
  State<BucketScreen> createState() => _BucketScreenState();
}

class _BucketScreenState extends State<BucketScreen> {
  final _events = bucketRef().onValue;
  final _controller = TextEditingController();

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    bucketRef()
        .push()
        .set({'text': text, 'done': false, 'by': widget.uid})
        .catchError(_saveFailed(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bucket list')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _EntryList(
                events: _events,
                emptyText: 'Nothing here yet.\nAdd the first thing below.',
                itemBuilder: (context, entry) {
                  final item = bucketRef().child(entry.key);
                  final done = entry.value['done'] == true;
                  return CheckboxListTile(
                    key: ValueKey(entry.key),
                    value: done,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('${entry.value['text'] ?? ''}'),
                    onChanged: (v) => item
                        .update({'done': v ?? false})
                        .catchError(_saveFailed(context)),
                    secondary: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          item.remove().catchError(_saveFailed(context)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(
                        labelText: 'Something to do together',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Add',
                    icon: const Icon(Icons.add),
                    onPressed: _add,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CountdownsScreen extends StatefulWidget {
  const CountdownsScreen({super.key});

  @override
  State<CountdownsScreen> createState() => _CountdownsScreenState();
}

class _CountdownsScreenState extends State<CountdownsScreen> {
  final _events = countdownsRef().onValue;

  Future<void> _add() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New countdown'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What is it for?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Pick date'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.isEmpty || !mounted) return;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 50),
    );
    if (date == null || !mounted) return;
    countdownsRef()
        .push()
        .set({'title': title, 'date': dayKey(date)})
        .catchError(_saveFailed(context));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Countdowns')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add countdown',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: _EntryList(
          events: _events,
          emptyText: 'No countdowns yet.\nTap + to add one.',
          sort: (a, b) => '${a.value['date']}'.compareTo('${b.value['date']}'),
          itemBuilder: (context, entry) => ListTile(
            key: ValueKey(entry.key),
            title: Text('${entry.value['title'] ?? ''}'),
            subtitle: Text('${entry.value['date'] ?? ''}'),
            leading: const Icon(Icons.event),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  countdownLabel(daysUntil(entry.value['date'], now)),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => countdownsRef()
                      .child(entry.key)
                      .remove()
                      .catchError(_saveFailed(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
