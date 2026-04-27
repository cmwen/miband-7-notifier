import 'package:flutter/material.dart';

import 'companion_home_page.dart';
import 'services/auth_key_extractor_service.dart';
import 'services/ble_companion_service.dart';
import 'services/ble_permission_service.dart';
import 'services/companion_repository.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();

  final companionRepository = CompanionRepository(
    storageService: storageService,
  );

  runApp(
    MiBandNotifierApp(
      notificationService: notificationService,
      companionRepository: companionRepository,
      authKeyExtractorService: const AuthKeyExtractorService(),
      blePermissionService: AndroidBlePermissionService(),
      bleCompanionService: ReactiveBleCompanionService(),
    ),
  );
}

class MiBandNotifierApp extends StatelessWidget {
  const MiBandNotifierApp({
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
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Band 7 Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6A00)),
        useMaterial3: true,
      ),
      home: CompanionHomePage(
        notificationService: notificationService,
        companionRepository: companionRepository,
        authKeyExtractorService: authKeyExtractorService,
        blePermissionService: blePermissionService,
        bleCompanionService: bleCompanionService,
      ),
    );
  }
}
