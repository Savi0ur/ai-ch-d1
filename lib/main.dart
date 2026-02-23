import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/chat_screen.dart';
import 'services/chat_repository.dart';

const _settingsBoxName = 'settings';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await ChatRepository.init();
  await Hive.openBox(_settingsBoxName);
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final _repository = ChatRepository();
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
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
