import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class AppColors {
  static const Color neutral50 = Color(0xFFF1F2F3);
  static const Color neutral100 = Color(0xFFD6D8DA);
  static const Color neutral200 = Color(0xFFADB1B8);
  static const Color neutral300 = Color(0xFF838996);
  static const Color neutral400 = Color(0xFF5F6777);
  static const Color neutral500 = Color(0xFF474D5B);
  static const Color neutral600 = Color(0xFF3A3F4D);
  static const Color neutral700 = Color(0xFF2D3340);
  static const Color neutral800 = Color(0xFF212633);
  static const Color neutral900 = Color(0xFF151923);
  static const Color neutral950 = Color(0xFF0F121A);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdShell',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.neutral50,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neutral500,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.neutral50,
          onSurface: AppColors.neutral900,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.neutral100,
          indicatorColor: AppColors.neutral200,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.neutral100,
          foregroundColor: AppColors.neutral900,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.neutral950,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.neutral500,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.neutral900,
          onSurface: AppColors.neutral50,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.neutral900,
          indicatorColor: AppColors.neutral700,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.neutral900,
          foregroundColor: AppColors.neutral50,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const Center(child: Text('Shell/Terminal')),
    const Center(child: Text('Saved Commands')),
    const Center(child: Text('App Manager')),
    const Center(child: Text('Device Info')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdShell'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.terminal),
            label: 'Shell',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}
