import 'package:flutter/material.dart';
import '../models/language_mode.dart';
import '../services/bible_service.dart';
import 'package:flutter/services.dart'; // ✅ 클립보드 기능 추가

class HomePageController extends ChangeNotifier {
  DateTime selectedDate = DateTime.now();
  LanguageMode languageMode = LanguageMode.korean;
  int currentPage = 0;
  final List<String> sheetNames = ["Old Testament", "New Testament", "Psalms"];
  final Map<int, Set<String>> selectedVerses = {};
  final Map<int, Future<Map<String, List<Widget>>>> cachedVerses = {};

  /// ✅ 특정 페이지의 성경 구절을 로드하는 함수
  void loadVersesForPage(int pageIndex, BuildContext context) {
    if (!cachedVerses.containsKey(pageIndex)) {
      cachedVerses[pageIndex] = loadGroupedBibleVerseWidgets(
        sheetNames[pageIndex], selectedDate, context,
        language: languageMode == LanguageMode.english ? "en"
            : languageMode == LanguageMode.compare ? "compare" : "kr",
      );
    }
  }

  /// ✅ 날짜 변경 시 호출
  void changeDate(DateTime newDate, BuildContext context) {
    selectedDate = newDate;
    cachedVerses.clear();
    selectedVerses.clear(); // ✅ 날짜 변경 시 선택 초기화
    notifyListeners();
    loadVersesForPage(currentPage, context);
  }

  /// ✅ 언어 변경 시 호출
  void changeLanguage(LanguageMode mode, BuildContext context) {
    languageMode = mode;
    cachedVerses.clear();
    selectedVerses.clear(); // ✅ 언어 변경 시 선택 초기화
    notifyListeners();
    loadVersesForPage(currentPage, context);
  }

  /// ✅ 성경 구절 선택/해제 기능 (일반 클릭 및 길게 누르기 지원)
  void toggleVerseSelection(int pageIndex, String verseKey, {bool isLongPress = false}) {
    selectedVerses.putIfAbsent(pageIndex, () => {});

    if (verseKey.isEmpty) {
      selectedVerses[pageIndex]!.clear(); // ✅ X 버튼을 누르면 초기화
    } else {
      if (selectedVerses[pageIndex]!.contains(verseKey)) {
        selectedVerses[pageIndex]!.remove(verseKey);
      } else {
        selectedVerses[pageIndex]!.add(verseKey);
      }
    }

    notifyListeners(); // UI 업데이트를 위해 호출
  }

  /// ✅ Copy 버튼 클릭 시 실행 (선택된 구절을 복사)
  void copySelectedVerses() {
    String formattedText = _formatSelectedVerses();
    Clipboard.setData(ClipboardData(text: formattedText));
  }

  /// ✅ 선택된 절을 특정 형식으로 변환
  String _formatSelectedVerses() {
    if (selectedVerses.isEmpty) return "";

    List<String> sortedVerses = selectedVerses.entries.expand((entry) => entry.value).toList()..sort();
    StringBuffer result = StringBuffer();
    String? lastBook = "";
    int? startVerse, endVerse;
    List<String> tempLines = [];

    for (String verse in sortedVerses) {
      var parts = verse.split(":");
      if (parts.length != 2) continue;

      String bookAndChapter = parts[0];
      int verseNumber = int.tryParse(parts[1]) ?? 0;

      if (lastBook != bookAndChapter) {
        if (startVerse != null) {
          result.writeln("$lastBook:$startVerse-$endVerse");
          result.writeln(tempLines.join("\n"));
          result.writeln();
        }
        lastBook = bookAndChapter;
        startVerse = endVerse = verseNumber;
        tempLines = ["$verseNumber. ${_getVerseText(verse)}"];
      } else {
        if (verseNumber == endVerse! + 1) {
          endVerse = verseNumber;
          tempLines.add("$verseNumber. ${_getVerseText(verse)}");
        } else {
          result.writeln("$lastBook:$startVerse-$endVerse");
          result.writeln(tempLines.join("\n"));
          result.writeln();
          startVerse = endVerse = verseNumber;
          tempLines = ["$verseNumber. ${_getVerseText(verse)}"];
        }
      }
    }

    if (startVerse != null) {
      result.writeln("$lastBook:$startVerse-$endVerse");
      result.writeln(tempLines.join("\n"));
    }

    return result.toString().trim();
  }

  /// ✅ 실제 성경 본문을 가져오는 함수 (현재는 더미 데이터)
  String _getVerseText(String verseKey) {
    return "본문 없음"; // ✅ 실제 데이터를 불러오는 로직 추가 필요
  }
}
