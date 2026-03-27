import 'dart:convert';

import 'package:flutter/material.dart';

import 'services/notification_service.dart';
import 'services/storage_service.dart';

const _draftTitleKey = 'draft_title';
const _draftBodyKey = 'draft_body';
const _historyKey = 'notification_history';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MiBandNotifierApp(
      storageService: storageService,
      notificationService: notificationService,
    ),
  );
}

class MiBandNotifierApp extends StatelessWidget {
  const MiBandNotifierApp({
    super.key,
    required this.storageService,
    required this.notificationService,
  });

  final StorageService storageService;
  final NotificationService notificationService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Band 7 Notifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6A00)),
        useMaterial3: true,
      ),
      home: NotifierHomePage(
        storageService: storageService,
        notificationService: notificationService,
      ),
    );
  }
}

class NotifierHomePage extends StatefulWidget {
  const NotifierHomePage({
    super.key,
    required this.storageService,
    required this.notificationService,
  });

  final StorageService storageService;
  final NotificationService notificationService;

  @override
  State<NotifierHomePage> createState() => _NotifierHomePageState();
}

class _NotifierHomePageState extends State<NotifierHomePage>
    with WidgetsBindingObserver {
  static const List<NotificationPreset> _presets = [
    NotificationPreset(
      label: 'Message',
      title: 'New message',
      body: 'Dinner starts at 7:30 PM. See you there.',
    ),
    NotificationPreset(
      label: 'Reminder',
      title: 'Stand-up in 5 minutes',
      body: 'Open your notes and get ready to join the daily sync.',
    ),
    NotificationPreset(
      label: 'Focus',
      title: 'Focus block started',
      body: 'Mute distractions and spend the next 30 minutes on one task.',
    ),
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  bool? _notificationsEnabled;
  bool _isBusy = false;
  List<NotificationHistoryEntry> _history = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _titleController = TextEditingController(
      text:
          widget.storageService.getString(_draftTitleKey) ??
          _presets.first.title,
    );
    _bodyController = TextEditingController(
      text:
          widget.storageService.getString(_draftBodyKey) ?? _presets.first.body,
    );
    _history = _loadHistory();
    _refreshNotificationState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationState();
    }
  }

  Future<void> _refreshNotificationState() async {
    final enabled = await widget.notificationService.areNotificationsEnabled();
    if (!mounted) {
      return;
    }

    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  List<NotificationHistoryEntry> _loadHistory() {
    final rawEntries = widget.storageService.getStringList(_historyKey) ?? [];
    return rawEntries
        .map((entry) => NotificationHistoryEntry.fromJson(jsonDecode(entry)))
        .toList(growable: false);
  }

  Future<void> _persistDraft() async {
    await widget.storageService.setString(
      _draftTitleKey,
      _titleController.text.trim(),
    );
    await widget.storageService.setString(
      _draftBodyKey,
      _bodyController.text.trim(),
    );
  }

  Future<void> _applyPreset(NotificationPreset preset) async {
    setState(() {
      _titleController.text = preset.title;
      _bodyController.text = preset.body;
    });
    await _persistDraft();
  }

  Future<void> _reuseHistoryEntry(NotificationHistoryEntry entry) async {
    setState(() {
      _titleController.text = entry.title;
      _bodyController.text = entry.body;
    });
    await _persistDraft();

    if (!mounted) {
      return;
    }

    _showMessage('Loaded a recent notification back into the composer.');
  }

  Future<void> _requestPermission() async {
    setState(() {
      _isBusy = true;
    });

    final granted = await widget.notificationService.requestPermission();
    await _refreshNotificationState();

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
    });

    final message = granted
        ? 'Notification permission is ready.'
        : 'Notification permission is still disabled.';
    _showMessage(message);
  }

  Future<void> _sendNotification() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      _showMessage('Add both a title and message before sending.');
      return;
    }

    setState(() {
      _isBusy = true;
    });

    await _persistDraft();
    await widget.notificationService.showNotification(title: title, body: body);

    final entry = NotificationHistoryEntry(
      title: title,
      body: body,
      sentAt: DateTime.now(),
    );
    final updatedHistory = [entry, ..._history].take(5).toList(growable: false);
    await widget.storageService.setStringList(
      _historyKey,
      updatedHistory.map((item) => jsonEncode(item.toJson())).toList(),
    );
    await _refreshNotificationState();

    if (!mounted) {
      return;
    }

    setState(() {
      _history = updatedHistory;
      _isBusy = false;
    });

    _showMessage(
      'Notification sent. If Mi Fitness mirrors this app, it should appear on your Mi Band 7.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        title: const Text('Mi Band 7 Notifier'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusCard(
                notificationsEnabled: _notificationsEnabled,
                onRefresh: _refreshNotificationState,
                onRequestPermission: _requestPermission,
                isBusy: _isBusy,
              ),
              const SizedBox(height: 16),
              Text(
                'Quick presets',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presets)
                    ActionChip(
                      label: Text(preset.label),
                      onPressed: _isBusy ? null : () => _applyPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compose notification',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Notification title',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bodyController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Notification body',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _isBusy ? null : _persistDraft,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save draft'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isBusy ? null : _sendNotification,
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Send to phone'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _GuideCard(),
              const SizedBox(height: 16),
              _HistoryCard(
                history: _history,
                onReuse: _isBusy ? null : _reuseHistoryEntry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.notificationsEnabled,
    required this.onRefresh,
    required this.onRequestPermission,
    required this.isBusy,
  });

  final bool? notificationsEnabled;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRequestPermission;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isEnabled = notificationsEnabled ?? false;
    final tone = notificationsEnabled == null
        ? Colors.blueGrey
        : (isEnabled ? Colors.green : Colors.orange);
    final icon = notificationsEnabled == null
        ? Icons.sync
        : (isEnabled ? Icons.check_circle : Icons.warning_amber);
    final label = notificationsEnabled == null
        ? 'Checking notification access...'
        : (isEnabled
              ? 'Notifications are enabled for this app.'
              : 'Notifications are blocked or not granted yet.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Mi Band 7 mirrors Android notifications through Mi Fitness or Zepp Life. '
              'This app posts a standard Android notification so the band can display it.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onRequestPermission,
                  icon: const Icon(Icons.notifications),
                  label: const Text('Request permission'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How to make it appear on Mi Band 7',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const _GuideStep(
              number: '1',
              text: 'Pair the band in Mi Fitness or Zepp Life.',
            ),
            const _GuideStep(
              number: '2',
              text: 'Enable app notification mirroring for Mi Band 7.',
            ),
            const _GuideStep(
              number: '3',
              text: 'Allow notifications for Mi Band 7 Notifier on your phone.',
            ),
            const _GuideStep(
              number: '4',
              text: 'Send a test notification from this app.',
            ),
            const SizedBox(height: 12),
            Text(
              'Note: Xiaomi does not expose an official public SDK for direct third-party app messaging to Mi Band 7, so notification mirroring is the reliable approach.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 12, child: Text(number)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history, required this.onReuse});

  final List<NotificationHistoryEntry> history;
  final Future<void> Function(NotificationHistoryEntry entry)? onReuse;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Tap an item to load it back into the composer.'),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('No notifications sent yet.')
            else
              for (final entry in history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(entry.title),
                  subtitle: Text('${entry.body}\n${entry.sentAtLabel}'),
                  isThreeLine: true,
                  enabled: onReuse != null,
                  onTap: onReuse == null ? null : () => onReuse!(entry),
                ),
          ],
        ),
      ),
    );
  }
}

class NotificationPreset {
  const NotificationPreset({
    required this.label,
    required this.title,
    required this.body,
  });

  final String label;
  final String title;
  final String body;
}

class NotificationHistoryEntry {
  const NotificationHistoryEntry({
    required this.title,
    required this.body,
    required this.sentAt,
  });

  factory NotificationHistoryEntry.fromJson(Map<String, dynamic> json) {
    return NotificationHistoryEntry(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      sentAt:
          DateTime.tryParse(json['sentAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String title;
  final String body;
  final DateTime sentAt;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'sentAt': sentAt.toIso8601String(),
  };

  String get sentAtLabel {
    final date = sentAt.toLocal();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
