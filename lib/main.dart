import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/communication_profile.dart';
import 'models/user_memory.dart';
import 'screens/chat_screen.dart';
import 'services/chat_repository.dart';
import 'services/communication_profile_service.dart';
import 'services/memory_service.dart';

const _settingsBoxName = 'settings';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  Hive.registerAdapter(UserMemoryAdapter());
  Hive.registerAdapter(CommunicationProfileAdapter());
  await ChatRepository.init();
  await Hive.openBox<UserMemory>('memory');
  await Hive.openBox(_settingsBoxName);
  await Hive.openBox<CommunicationProfile>('profiles');
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _repository = ChatRepository();
  final _memoryService = MemoryService();
  final _profileService = CommunicationProfileService();
  late final Box _settingsBox = Hive.box(_settingsBoxName);

  bool get _isDark => _settingsBox.get('isDark', defaultValue: false) as bool;

  void _toggleTheme() {
    setState(() {
      _settingsBox.put('isDark', !_isDark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: ChatScreen(
        repository: _repository,
        memoryService: _memoryService,
        profileService: _profileService,
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
