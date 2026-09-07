import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class AppColors {
  static const Color primary = Color(0xFF8B5CF6); // Violet/Purple
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
        scaffoldBackgroundColor: AppColors.neutral100, // Different from header/tab
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          surface: AppColors.neutral50,
          onSurface: AppColors.neutral900,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.neutral50, // Different from root
          elevation: 0,
          centerTitle: true,
          foregroundColor: AppColors.neutral900,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.neutral950, // Root background
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          surface: AppColors.neutral900,
          onSurface: AppColors.neutral50,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.neutral900, // Different from root
          elevation: 0,
          centerTitle: true,
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

  Widget _buildNavItem(BuildContext context, {required IconData icon, required int index}) {
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center( // Wraps InkWell to ensure perfect vertical centering within the 72 height
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.15) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected 
                  ? AppColors.primary 
                  : (isDark ? AppColors.neutral400 : AppColors.neutral500),
              size: 26,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackgroundColor = isDark ? AppColors.neutral900 : AppColors.neutral50;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AdShell', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 72 + MediaQuery.of(context).padding.bottom, // Account for system navigation bar height
        color: navBackgroundColor,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom), // Push content up
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(context, icon: _selectedIndex == 0 ? Icons.terminal : Icons.terminal_outlined, index: 0),
            _buildNavItem(context, icon: _selectedIndex == 1 ? Icons.bookmark : Icons.bookmark_border, index: 1),
            _buildNavItem(context, icon: _selectedIndex == 2 ? Icons.grid_view_rounded : Icons.grid_view, index: 2),
            _buildNavItem(context, icon: _selectedIndex == 3 ? Icons.info : Icons.info_outline, index: 3),
          ],
        ),
      ),
    );
  }
}
