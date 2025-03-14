import 'package:flutter/material.dart';
import '../services/bible_service.dart';
import 'package:flutter/services.dart'; // ✅ 클립보드 복사 기능 추가

class BibleTodaySheet extends StatelessWidget {
  final String sheetTitle;
  final DateTime selectedDate;
  final String language;
  final Function(String, {bool isLongPress}) onVerseSelected;
  final Set<String> selectedVerses;
  final Future<Map<String, List<Widget>>> versesFuture;

  const BibleTodaySheet({
    super.key,
    required this.sheetTitle,
    required this.selectedDate,
    required this.language,
    required this.onVerseSelected,
    required this.selectedVerses,
    required this.versesFuture,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<Map<String, List<Widget>>>(
          future: versesFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("오늘 읽을 성경 본문이 없습니다."));
            }
            var groupedWidgets = snapshot.data!;
            return ListView(
              children: groupedWidgets.entries.expand((entry) {
                return entry.value.map((verseWidget) {
                  String verseKey = verseWidget.hashCode.toString();
                  return GestureDetector(
                    onTap: () => onVerseSelected(verseKey),
                    onLongPress: () => onVerseSelected(verseKey, isLongPress: true),
                    child: Container(
                      color: selectedVerses.contains(verseKey)
                          ? Colors.grey.withOpacity(0.5)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
                      child: verseWidget,
                    ),
                  );
                }).toList();
              }).toList(),
            );
          },
        ),
        if (selectedVerses.isNotEmpty) Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            children: [
              FloatingActionButton.extended(
                onPressed: () {
                  _copySelectedVerses();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("구절이 복사되었습니다!")),
                  );
                },
                label: const Text("Copy"),
                icon: const Icon(Icons.copy),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                onPressed: () => onVerseSelected("", isLongPress: true),
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copySelectedVerses() {
    String formattedText = _formatSelectedVerses();
    Clipboard.setData(ClipboardData(text: formattedText));
  }

  String _formatSelectedVerses() {
    if (selectedVerses.isEmpty) return "";

    List<String> sortedVerses = selectedVerses.toList()..sort();
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

  String _getVerseText(String verseKey) {
    return "본문 없음"; // 실제 성경 데이터에서 가져와야 함
  }
}
