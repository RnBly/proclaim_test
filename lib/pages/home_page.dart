import 'package:flutter/material.dart';
import '../dialogs/date_selection_dialog.dart';
import '../services/bible_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/bible_today_sheet.dart';
import '../widgets/navigation_controls.dart'; // ✅ 화살표 기능 import

enum LanguageMode { korean, english, compare }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<String> sheetNames = ["Old Testament", "New Testament", "Psalms"];
  late PageController _pageController;
  int _currentPage = 0;
  DateTime selectedDate = DateTime.now();
  LanguageMode languageMode = LanguageMode.korean;
  Map<int, Set<String>> selectedVerses = {};
  Map<int, Future<Map<String, List<Widget>>>> cachedVerses = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentPage);
    _loadVersesForPage(0);
  }

  void _loadVersesForPage(int pageIndex) {
    if (!cachedVerses.containsKey(pageIndex)) {
      cachedVerses[pageIndex] = loadGroupedBibleVerseWidgets(
        sheetNames[pageIndex], selectedDate, context,
        language: languageMode == LanguageMode.english ? "en"
            : languageMode == LanguageMode.compare ? "compare" : "kr",
      );
    }
  }

  void _openDateSelection() async {
    DateTime? newDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => DateSelectionDialog(initialDate: selectedDate),
    );
    if (newDate != null) {
      setState(() {
        selectedDate = newDate;
        cachedVerses.clear();
        _loadVersesForPage(_currentPage);
      });
    }
  }

  void _openLanguageSelectionDialog() async {
    await showDialog<LanguageMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("언어 선택"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("개역개정"),
                onTap: () => _changeLanguage(LanguageMode.korean),
              ),
              ListTile(
                title: const Text("ESV"),
                onTap: () => _changeLanguage(LanguageMode.english),
              ),
              ListTile(
                title: const Text("한영 비교"),
                onTap: () => _changeLanguage(LanguageMode.compare),
              ),
            ],
          ),
        );
      },
    );
  }

  void _changeLanguage(LanguageMode mode) async {
    setState(() {
      languageMode = mode;
      cachedVerses.clear();
      _loadVersesForPage(_currentPage);
    });
    Navigator.pop(context);
  }

  void _toggleVerseSelection(int pageIndex, String verseKey, {bool isLongPress = false}) {
    setState(() {
      selectedVerses.putIfAbsent(pageIndex, () => {});
      if (selectedVerses[pageIndex]!.contains(verseKey)) {
        selectedVerses[pageIndex]!.remove(verseKey);
      } else {
        selectedVerses[pageIndex]!.add(verseKey);
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _loadVersesForPage(index);
  }

  @override
  Widget build(BuildContext context) {
    String titleText;
    switch (languageMode) {
      case LanguageMode.english:
        titleText = "Today's Bible (${formatToday(selectedDate)})";
        break;
      case LanguageMode.compare:
        titleText = "한영 대조 성경 말씀 (${formatToday(selectedDate)})";
        break;
      case LanguageMode.korean:
        titleText = "오늘의 성경 말씀 (${formatToday(selectedDate)})";
        break;
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: GestureDetector(
          onTap: _openDateSelection,
          child: Text(titleText),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate),
            onPressed: _openLanguageSelectionDialog,
          ),
          NavigationControls( // ✅ 화살표 import한 컴포넌트 사용
            pageController: _pageController,
            currentPage: _currentPage,
            totalPages: sheetNames.length,
            onPageChanged: _onPageChanged,
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: sheetNames.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          return BibleTodaySheet(
            sheetTitle: sheetNames[index],
            selectedDate: selectedDate,
            language: languageMode == LanguageMode.english ? "en"
                : languageMode == LanguageMode.compare ? "compare" : "kr",
            onVerseSelected: (String verseKey, {bool isLongPress = false}) {
              _toggleVerseSelection(index, verseKey, isLongPress: isLongPress);
            },
            selectedVerses: selectedVerses[index] ?? {},
            versesFuture: cachedVerses[index]!,
          );
        },
      ),
    );
  }
}
