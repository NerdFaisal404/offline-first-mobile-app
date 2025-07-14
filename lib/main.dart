import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'presentation/pages/todo_home_page.dart';
import 'presentation/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase safely
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase might already be initialized by the platform
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
    } else {
      print('Firebase initialization error: $e');
      rethrow;
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Offline Todo App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends ConsumerStatefulWidget {
  const AppInitializer({super.key});

  @override
  ConsumerState<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize device ID
    await ref.read(deviceIdProvider.future);

    // Start sync service
    final syncService = ref.read(syncServiceProvider);
    await syncService.start();
  }

  @override
  void dispose() {
    // Stop sync service
    final syncService = ref.read(syncServiceProvider);
    syncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceIdAsync = ref.watch(deviceIdProvider);

    return deviceIdAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error initializing app: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(deviceIdProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (deviceId) => const TodoHomePage(),
    );
  }
}
