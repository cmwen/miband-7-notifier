import 'package:flutter/material.dart';

import 'models/companion_models.dart';
import 'services/auth_key_extractor_service.dart';
import 'services/ble_companion_service.dart';
import 'services/ble_permission_service.dart';
import 'services/companion_repository.dart';
import 'services/notification_service.dart';

class CompanionHomePage extends StatefulWidget {
  const CompanionHomePage({
    super.key,
    required this.notificationService,
    required this.companionRepository,
    required this.authKeyExtractorService,
    required this.blePermissionService,
    required this.bleCompanionService,
  });

  final NotificationService notificationService;
  final CompanionRepository companionRepository;
  final AuthKeyExtractorService authKeyExtractorService;
  final BlePermissionService blePermissionService;
  final BleCompanionService bleCompanionService;

  @override
  State<CompanionHomePage> createState() => _CompanionHomePageState();
}

class _CompanionHomePageState extends State<CompanionHomePage> {
  late final TextEditingController _rawAuthSourceController;
  late final TextEditingController _deviceNameController;
  late final TextEditingController _deviceIdController;

  CompanionConfig _config = CompanionConfig.initial();
  BlePermissionSnapshot _permissionSnapshot =
      const BlePermissionSnapshot.unknown();
  List<CompanionJournalEntry> _journal = const [];
  List<AuthKeyCandidate> _authKeyCandidates = const [];
  List<ScannedBand> _scanResults = const [];
  bool _isLoading = true;
  bool _isSavingPairing = false;
  bool _isRequestingPermissions = false;
  bool _isScanning = false;
  bool _isSendingRelayTest = false;

  @override
  void initState() {
    super.initState();
    _rawAuthSourceController = TextEditingController();
    _deviceNameController = TextEditingController();
    _deviceIdController = TextEditingController();
    _loadState();
  }

  @override
  void dispose() {
    _rawAuthSourceController.dispose();
    _deviceNameController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final config = await widget.companionRepository.loadConfig();
    final journal = await widget.companionRepository.loadJournal();
    final permissions = await widget.blePermissionService.getSnapshot();

    if (!mounted) {
      return;
    }

    _deviceNameController.text = config.deviceName;
    _deviceIdController.text = config.deviceId;

    setState(() {
      _config = config;
      _journal = journal;
      _permissionSnapshot = permissions;
      _isLoading = false;
    });
  }

  Future<void> _savePairingDetails() async {
    setState(() {
      _isSavingPairing = true;
    });

    final updatedConfig = _config.copyWith(
      deviceName: _deviceNameController.text.trim(),
      deviceId: _deviceIdController.text.trim(),
      updatedAt: DateTime.now(),
    );

    await widget.companionRepository.saveConfig(updatedConfig);
    final journal = await widget.companionRepository.appendJournalEntry(
      message:
          'Updated pairing notes for ${updatedConfig.vendorApp.label} and stored device hints.',
      level: CompanionLogLevel.info,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _config = updatedConfig;
      _journal = journal;
      _isSavingPairing = false;
    });

    _showMessage('Saved pairing details.');
  }

  Future<void> _updateVendorApp(VendorAppKind vendorApp) async {
    final updatedConfig = _config.copyWith(
      vendorApp: vendorApp,
      updatedAt: DateTime.now(),
    );
    await widget.companionRepository.saveConfig(updatedConfig);

    if (!mounted) {
      return;
    }

    setState(() {
      _config = updatedConfig;
    });
  }

  Future<void> _setOfficialPairingCompleted(bool value) async {
    final updatedConfig = _config.copyWith(
      officialPairingCompleted: value,
      updatedAt: DateTime.now(),
    );
    await widget.companionRepository.saveConfig(updatedConfig);
    final journal = await widget.companionRepository.appendJournalEntry(
      message: value
          ? 'Marked official vendor pairing as complete. Do not unpair in the vendor app.'
          : 'Marked official vendor pairing as incomplete.',
      level: value ? CompanionLogLevel.success : CompanionLogLevel.warning,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _config = updatedConfig;
      _journal = journal;
    });
  }

  Future<void> _extractAuthKeys() async {
    final raw = _rawAuthSourceController.text.trim();
    if (raw.isEmpty) {
      _showMessage(
        'Paste a Mi Fitness log, rooted DB output, or a raw auth key.',
      );
      return;
    }

    final candidates = widget.authKeyExtractorService.extractCandidates(raw);
    final journal = await widget.companionRepository.appendJournalEntry(
      message: candidates.isEmpty
          ? 'Could not find a 32-byte auth key in the pasted content.'
          : 'Parsed ${candidates.length} auth key candidate(s) from pasted content.',
      level: candidates.isEmpty
          ? CompanionLogLevel.warning
          : CompanionLogLevel.success,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _authKeyCandidates = candidates;
      _journal = journal;
    });

    if (candidates.isEmpty) {
      _showMessage('No auth key candidates found.');
    }
  }

  Future<void> _useAuthKey(AuthKeyCandidate candidate) async {
    final updatedConfig = _config.copyWith(
      authKey: candidate.normalizedKey,
      authKeySource: candidate.source,
      updatedAt: DateTime.now(),
    );

    await widget.companionRepository.saveConfig(updatedConfig);
    final journal = await widget.companionRepository.appendJournalEntry(
      message: 'Imported auth key from ${candidate.sourceLabel}.',
      level: CompanionLogLevel.success,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _config = updatedConfig;
      _journal = journal;
    });

    _showMessage('Saved auth key for future BLE pairing.');
  }

  Future<void> _requestBlePermissions() async {
    setState(() {
      _isRequestingPermissions = true;
    });

    final snapshot = await widget.blePermissionService
        .requestRequiredPermissions();
    final journal = await widget.companionRepository.appendJournalEntry(
      message: snapshot.canDiscoverDevices
          ? 'BLE discovery permissions are ready.'
          : 'BLE discovery permissions are still incomplete.',
      level: snapshot.canDiscoverDevices
          ? CompanionLogLevel.success
          : CompanionLogLevel.warning,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _permissionSnapshot = snapshot;
      _journal = journal;
      _isRequestingPermissions = false;
    });
  }

  Future<void> _scanForBands() async {
    if (!_permissionSnapshot.canDiscoverDevices) {
      _showMessage('Grant BLE permissions before starting a scan.');
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      final bands = await widget.bleCompanionService.scanForBands();
      final journal = await widget.companionRepository.appendJournalEntry(
        message: bands.isEmpty
            ? 'BLE scan finished without a Mi Band style advertisement.'
            : 'BLE scan found ${bands.length} relevant device candidate(s).',
        level: bands.isEmpty
            ? CompanionLogLevel.warning
            : CompanionLogLevel.success,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _scanResults = bands;
        _journal = journal;
        _isScanning = false;
      });
    } catch (error) {
      final journal = await widget.companionRepository.appendJournalEntry(
        message: 'BLE scan failed: $error',
        level: CompanionLogLevel.warning,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _journal = journal;
        _isScanning = false;
      });
      _showMessage('BLE scan failed. Check the companion journal.');
    }
  }

  Future<void> _useScannedBand(ScannedBand band) async {
    _deviceNameController.text = band.displayName;
    _deviceIdController.text = band.id;

    final updatedConfig = _config.copyWith(
      deviceName: band.displayName,
      deviceId: band.id,
      updatedAt: DateTime.now(),
    );
    await widget.companionRepository.saveConfig(updatedConfig);
    final journal = await widget.companionRepository.appendJournalEntry(
      message:
          'Remembered ${band.displayName} (${band.id}) as the target band.',
      level: CompanionLogLevel.success,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _config = updatedConfig;
      _journal = journal;
    });
  }

  Future<void> _sendRelaySmokeTest() async {
    setState(() {
      _isSendingRelayTest = true;
    });

    try {
      var notificationsEnabled = await widget.notificationService
          .areNotificationsEnabled();
      if (!notificationsEnabled) {
        notificationsEnabled = await widget.notificationService
            .requestPermission();
      }

      if (!notificationsEnabled) {
        final journal = await widget.companionRepository.appendJournalEntry(
          message:
              'Relay smoke test blocked because Android notifications are disabled.',
          level: CompanionLogLevel.warning,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _journal = journal;
          _isSendingRelayTest = false;
        });
        _showMessage(
          'Enable Android notifications before running the smoke test.',
        );
        return;
      }

      await widget.notificationService.showNotification(
        title: 'Mi Band 7 Companion',
        body:
            'Relay smoke test. If your official app still mirrors notifications, the band should vibrate now.',
      );
      final journal = await widget.companionRepository.appendJournalEntry(
        message: 'Posted a relay smoke-test notification to Android.',
        level: CompanionLogLevel.info,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _journal = journal;
        _isSendingRelayTest = false;
      });

      _showMessage('Relay smoke test sent.');
    } catch (error) {
      final journal = await widget.companionRepository.appendJournalEntry(
        message: 'Relay smoke test failed: $error',
        level: CompanionLogLevel.warning,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _journal = journal;
        _isSendingRelayTest = false;
      });
      _showMessage('Relay smoke test failed. Check the companion journal.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int get _completedReadinessSteps {
    final steps = [
      _config.officialPairingCompleted,
      _config.hasAuthKey,
      _permissionSnapshot.canDiscoverDevices,
      _scanResults.isNotEmpty || _config.deviceId.isNotEmpty,
    ];
    return steps.where((step) => step).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Band 7 Companion')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadState,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gadgetbridge-style rework started',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'This app is being reworked into a real companion foundation: vendor-paired auth key import, BLE discovery, and the groundwork for background connectivity.',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: const [
                                Chip(label: Text('Auth key intake')),
                                Chip(label: Text('BLE discovery')),
                                Chip(label: Text('Background prep')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Companion readiness',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                Text('$_completedReadinessSteps / 4'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: _completedReadinessSteps / 4,
                            ),
                            const SizedBox(height: 16),
                            _ReadinessRow(
                              title: 'Official pairing completed',
                              subtitle:
                                  'Pair in ${_config.vendorApp.label} first, then do not unpair there.',
                              isReady: _config.officialPairingCompleted,
                            ),
                            _ReadinessRow(
                              title: 'Auth key imported',
                              subtitle: _config.hasAuthKey
                                  ? 'Current key source: ${_config.authKeySource.label}.'
                                  : 'Paste raw logs, rooted DB output, or a token-tool result below.',
                              isReady: _config.hasAuthKey,
                            ),
                            _ReadinessRow(
                              title: 'BLE permissions ready',
                              subtitle: _permissionSnapshot.canDiscoverDevices
                                  ? 'Scan + connect permissions are granted.'
                                  : 'Bluetooth scan/connect and location are still needed.',
                              isReady: _permissionSnapshot.canDiscoverDevices,
                            ),
                            _ReadinessRow(
                              title: 'Band candidate identified',
                              subtitle: _config.deviceId.isNotEmpty
                                  ? 'Target device: ${_config.deviceName.isEmpty ? _config.deviceId : '${_config.deviceName} (${_config.deviceId})'}.'
                                  : 'Run a BLE scan and pin the device you want to target.',
                              isReady:
                                  _scanResults.isNotEmpty ||
                                  _config.deviceId.isNotEmpty,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vendor pairing baseline',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<VendorAppKind>(
                              initialValue: _config.vendorApp,
                              decoration: const InputDecoration(
                                labelText:
                                    'Vendor app used for initial pairing',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                for (final vendorApp in VendorAppKind.values)
                                  DropdownMenuItem(
                                    value: vendorApp,
                                    child: Text(
                                      '${vendorApp.label} (${vendorApp.packageName})',
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                _updateVendorApp(value);
                              },
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile.adaptive(
                              value: _config.officialPairingCompleted,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'I have already paired the band in the vendor app',
                              ),
                              subtitle: const Text(
                                'Do not unpair there, or the auth key becomes invalid.',
                              ),
                              onChanged: _setOfficialPairingCompleted,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _deviceNameController,
                              decoration: const InputDecoration(
                                labelText: 'Expected band name',
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _deviceIdController,
                              decoration: const InputDecoration(
                                labelText: 'Remembered BLE device ID / MAC',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isSavingPairing
                                  ? null
                                  : _savePairingDetails,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save pairing baseline'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auth key workshop',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Paste Mi Fitness logs, rooted database output, huami-token output, or a manual 32-byte key. The app normalizes it into the `0x...` format Gadgetbridge expects.',
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _rawAuthSourceController,
                              minLines: 6,
                              maxLines: 8,
                              decoration: const InputDecoration(
                                labelText: 'Paste raw auth output',
                                border: OutlineInputBorder(),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _extractAuthKeys,
                              icon: const Icon(Icons.key),
                              label: const Text('Extract auth key candidates'),
                            ),
                            if (_config.hasAuthKey) ...[
                              const SizedBox(height: 12),
                              SelectableText(
                                'Current auth key: ${_config.authKey!}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                            if (_authKeyCandidates.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Candidates',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              for (final candidate in _authKeyCandidates)
                                Card.outlined(
                                  child: ListTile(
                                    title: Text(candidate.normalizedKey),
                                    subtitle: Text(candidate.sourceLabel),
                                    trailing: TextButton(
                                      onPressed: () => _useAuthKey(candidate),
                                      child: const Text('Use this key'),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BLE discovery prep',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _PermissionChip(
                                  label: 'Scan',
                                  isGranted:
                                      _permissionSnapshot.bluetoothScanGranted,
                                ),
                                _PermissionChip(
                                  label: 'Connect',
                                  isGranted: _permissionSnapshot
                                      .bluetoothConnectGranted,
                                ),
                                _PermissionChip(
                                  label: 'Location',
                                  isGranted:
                                      _permissionSnapshot.locationGranted,
                                ),
                                _PermissionChip(
                                  label: 'Notifications',
                                  isGranted:
                                      _permissionSnapshot.notificationGranted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _isRequestingPermissions
                                      ? null
                                      : _requestBlePermissions,
                                  icon: const Icon(Icons.bluetooth_searching),
                                  label: const Text('Request BLE permissions'),
                                ),
                                FilledButton.icon(
                                  onPressed: _isScanning ? null : _scanForBands,
                                  icon: const Icon(Icons.radar),
                                  label: Text(
                                    _isScanning
                                        ? 'Scanning...'
                                        : 'Scan for nearby bands',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'This is the first discovery slice only. Background reconnect, authenticated sessions, and protocol work come next.',
                            ),
                            if (_scanResults.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Scan results',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 8),
                              for (final band in _scanResults)
                                Card.outlined(
                                  child: ListTile(
                                    title: Text(band.displayName),
                                    subtitle: Text(
                                      '${band.id}\nRSSI ${band.rssi} • ${band.connectable ? 'connectable' : 'not connectable'}',
                                    ),
                                    isThreeLine: true,
                                    trailing: TextButton(
                                      onPressed: () => _useScannedBand(band),
                                      child: const Text('Use device'),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notification relay smoke test',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'While direct band protocol work is being built, this still helps verify that your phone-side notification path is alive.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isSendingRelayTest
                                  ? null
                                  : _sendRelaySmokeTest,
                              icon: const Icon(Icons.notifications_active),
                              label: const Text('Send relay smoke test'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Companion journal',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (_journal.isEmpty)
                              const Text('No journal entries yet.')
                            else
                              for (final entry in _journal)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(switch (entry.level) {
                                    CompanionLogLevel.success =>
                                      Icons.check_circle_outline,
                                    CompanionLogLevel.warning =>
                                      Icons.warning_amber_outlined,
                                    CompanionLogLevel.info =>
                                      Icons.info_outline,
                                  }),
                                  title: Text(entry.message),
                                  subtitle: Text(
                                    '${entry.level.label} • ${entry.createdAtLabel}',
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.subtitle,
    required this.isReady,
  });

  final String title;
  final String subtitle;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isReady ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isReady ? Colors.green : null,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label, required this.isGranted});

  final String label;
  final bool isGranted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isGranted ? Icons.check : Icons.close,
        size: 18,
        color: isGranted ? Colors.green : Colors.redAccent,
      ),
      label: Text(label),
    );
  }
}
