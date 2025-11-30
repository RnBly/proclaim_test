import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/meditation.dart';
import 'copy_dialog.dart';
import '../services/bible_service.dart';

// 묵상 조회 다이얼로그
class MeditationViewDialog extends StatefulWidget {
  final List<Meditation> meditations; // 해당 구절의 모든 묵상들
  final int initialIndex; // 초기 표시할 묵상 인덱스
  final Function(Meditation)? onEdit; // 수정 콜백
  final Function(String)? onDelete; // 삭제 콜백

  const MeditationViewDialog({
    super.key,
    required this.meditations,
    this.initialIndex = 0,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<MeditationViewDialog> createState() => _MeditationViewDialogState();
}

class _MeditationViewDialogState extends State<MeditationViewDialog> {
  late int _currentIndex;
  final ScrollController _contentScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    _contentScrollController.dispose();
    super.dispose();
  }

  Meditation get _currentMeditation => widget.meditations[_currentIndex];

  String _formatDate(DateTime date) {
    return DateFormat('M월 d일').format(date);
  }

  // 본문(구절) 복사 함수 - 절 선택 복사와 동일한 방식으로 변경
  void _copyVerses() {
    showDialog(
      context: context,
      builder: (context) => CopyDialog(
        onFormatSelected: (format) async {
          String formatted = '';

          if (format == CopyFormat.korean) {
            formatted = _getKoreanFormat();
          } else if (format == CopyFormat.esv) {
            formatted = _getEsvFormat();
          } else {
            formatted = _getCompareFormat();
          }

          await Clipboard.setData(ClipboardData(text: formatted));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('복사 되었습니다'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  // 개역개정 형식
  String _getKoreanFormat() {
    final verses = _currentMeditation.verses;
    if (verses.isEmpty) return '';

    // 책, 장별로 그룹화
    final Map<String, Map<int, List<VerseReference>>> grouped = {};

    for (var verse in verses) {
      if (!grouped.containsKey(verse.book)) {
        grouped[verse.book] = {};
      }
      if (!grouped[verse.book]!.containsKey(verse.chapter)) {
        grouped[verse.book]![verse.chapter] = [];
      }
      grouped[verse.book]![verse.chapter]!.add(verse);
    }

    final StringBuffer buffer = StringBuffer();

    grouped.forEach((book, chapters) {
      chapters.forEach((chapter, verseList) {
        // 연속된 절 범위 계산
        verseList.sort((a, b) => a.verse.compareTo(b.verse));

        if (verseList.length == 1) {
          final v = verseList.first;
          buffer.writeln('[${v.displayText}]');
          buffer.writeln('${v.verse}. ${v.text}');
        } else {
          final first = verseList.first;
          final last = verseList.last;
          buffer.writeln('[${first.book} ${first.chapter}:${first.verse}-${last.verse}]');
          for (var v in verseList) {
            buffer.writeln('${v.verse}. ${v.text}');
          }
        }
        buffer.writeln();
      });
    });

    return buffer.toString().trim();
  }

  // ESV 형식
  String _getEsvFormat() {
    final verses = _currentMeditation.verses;
    if (verses.isEmpty) return '';

    // ESV 텍스트와 영문 책명을 저장할 리스트
    final List<Map<String, dynamic>> esvVerses = [];

    for (var verse in verses) {
      final bookEng = _convertToEngBook(verse.book);

      // BibleService에서 ESV 텍스트 가져오기
      final esvText = BibleService().getEsvVerses(
        bookEng,
        verse.chapter,
        verse.chapter,
        verseRange: '${verse.verse}-${verse.verse}',
      );

      if (esvText.isNotEmpty) {
        esvVerses.add({
          'bookEng': bookEng,
          'chapter': verse.chapter,
          'verse': verse.verse,
          'text': esvText.first.text,
        });
      }
    }

    if (esvVerses.isEmpty) return '';

    // 책, 장별로 그룹화
    final Map<String, Map<int, List<Map<String, dynamic>>>> grouped = {};

    for (var verse in esvVerses) {
      final bookEng = verse['bookEng'] as String;
      final chapter = verse['chapter'] as int;

      if (!grouped.containsKey(bookEng)) {
        grouped[bookEng] = {};
      }
      if (!grouped[bookEng]!.containsKey(chapter)) {
        grouped[bookEng]![chapter] = [];
      }
      grouped[bookEng]![chapter]!.add(verse);
    }

    final StringBuffer buffer = StringBuffer();

    grouped.forEach((book, chapters) {
      chapters.forEach((chapter, verseList) {
        verseList.sort((a, b) => (a['verse'] as int).compareTo(b['verse'] as int));

        if (verseList.length == 1) {
          final v = verseList.first;
          buffer.writeln('[${book} ${v['chapter']}:${v['verse']}]');
          buffer.writeln('${v['verse']}. ${v['text']}');
        } else {
          final first = verseList.first;
          final last = verseList.last;
          buffer.writeln('[${book} ${first['chapter']}:${first['verse']}-${last['verse']}]');
          for (var v in verseList) {
            buffer.writeln('${v['verse']}. ${v['text']}');
          }
        }
        buffer.writeln();
      });
    });

    return buffer.toString().trim();
  }

  // 역본대조 형식
  String _getCompareFormat() {
    final verses = _currentMeditation.verses;
    if (verses.isEmpty) return '';

    // ESV 텍스트 가져오기
    final Map<String, String> esvTexts = {};

    for (var verse in verses) {
      final key = '${verse.book}-${verse.chapter}-${verse.verse}';
      final bookEng = _convertToEngBook(verse.book);

      final esvText = BibleService().getEsvVerses(
        bookEng,
        verse.chapter,
        verse.chapter,
        verseRange: '${verse.verse}-${verse.verse}',
      );

      if (esvText.isNotEmpty) {
        esvTexts[key] = esvText.first.text;
      }
    }

    // 책, 장별로 그룹화
    final Map<String, Map<int, List<VerseReference>>> grouped = {};

    for (var verse in verses) {
      if (!grouped.containsKey(verse.book)) {
        grouped[verse.book] = {};
      }
      if (!grouped[verse.book]!.containsKey(verse.chapter)) {
        grouped[verse.book]![verse.chapter] = [];
      }
      grouped[verse.book]![verse.chapter]!.add(verse);
    }

    final StringBuffer buffer = StringBuffer();

    grouped.forEach((book, chapters) {
      chapters.forEach((chapter, verseList) {
        verseList.sort((a, b) => a.verse.compareTo(b.verse));

        if (verseList.length == 1) {
          final v = verseList.first;
          buffer.writeln('[${v.displayText}]');
          buffer.writeln('${v.verse}. ${v.text}');
          final key = '${v.book}-${v.chapter}-${v.verse}';
          if (esvTexts.containsKey(key)) {
            buffer.writeln('${v.verse}. ${esvTexts[key]}');
          }
        } else {
          final first = verseList.first;
          final last = verseList.last;
          buffer.writeln('[${first.book} ${first.chapter}:${first.verse}-${last.verse}]');
          for (var v in verseList) {
            buffer.writeln('${v.verse}. ${v.text}');
            final key = '${v.book}-${v.chapter}-${v.verse}';
            if (esvTexts.containsKey(key)) {
              buffer.writeln('${v.verse}. ${esvTexts[key]}');
            }
          }
        }
        buffer.writeln();
      });
    });

    return buffer.toString().trim();
  }

  // 한글 책명을 영문으로 변환
  String _convertToEngBook(String koreanBook) {
    final Map<String, String> bookMap = {
      '창': 'Gen', '출': 'Exo', '레': 'Lev', '민': 'Num', '신': 'Deu',
      '수': 'Jos', '삿': 'Jdg', '룻': 'Rut', '삼상': '1Sa', '삼하': '2Sa',
      '왕상': '1Ki', '왕하': '2Ki', '대상': '1Ch', '대하': '2Ch',
      '스': 'Ezr', '느': 'Neh', '에': 'Est', '욥': 'Job', '시': 'Psa',
      '잠': 'Pro', '전': 'Ecc', '아': 'Sng', '사': 'Isa', '렘': 'Jer',
      '애': 'Lam', '겔': 'Eze', '단': 'Dan', '호': 'Hos', '욜': 'Joe',
      '암': 'Amo', '옵': 'Oba', '욘': 'Jon', '미': 'Mic', '나': 'Nah',
      '합': 'Hab', '습': 'Zep', '학': 'Hag', '슥': 'Zec', '말': 'Mal',
      '마': 'Mat', '막': 'Mar', '눅': 'Luk', '요': 'Joh', '행': 'Act',
      '롬': 'Rom', '고전': '1Co', '고후': '2Co', '갈': 'Gal', '엡': 'Eph',
      '빌': 'Php', '골': 'Col', '살전': '1Th', '살후': '2Th', '딤전': '1Ti',
      '딤후': '2Ti', '딛': 'Tit', '몬': 'Phm', '히': 'Heb', '약': 'Jam',
      '벧전': '1Pe', '벧후': '2Pe', '요일': '1Jn', '요이': '2Jn', '요삼': '3Jn',
      '유': 'Jud', '계': 'Rev',
    };
    return bookMap[koreanBook] ?? koreanBook;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 날짜 (여러 묵상이 있는 경우 드롭다운)
                Expanded(
                  child: widget.meditations.length > 1
                      ? _buildDateDropdown()
                      : Text(
                    _buildDateLabel(0),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // 선택된 구절들 - 복사 가능하게 수정
            Expanded(
              flex: 2, // 전체의 약 2/5
              child: InkWell(
                onTap: _copyVerses,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Stack(
                    children: [
                      // 구절 내용 - 오른쪽에 패딩 추가하여 복사 버튼과 겹침 방지
                      Padding(
                        padding: const EdgeInsets.only(right: 32), // 복사 버튼 공간 확보
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _currentMeditation.verses.map((verse) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildVerseItem(verse),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                      // 오른쪽 위 복사 아이콘
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.content_copy, size: 18),
                          color: Colors.grey.shade600,
                          onPressed: _copyVerses,
                          tooltip: '본문 복사',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 묵상 내용 섹션
            const Text(
              '나의 묵상',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // 묵상 내용 - Expanded로 남은 공간 사용
            Expanded(
              flex: 3, // 전체의 약 3/5
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Scrollbar(
                  controller: _contentScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _contentScrollController,
                    child: Text(
                      _currentMeditation.content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 삭제/수정 버튼
            Row(
              children: [
                // 삭제 버튼
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onDelete?.call(_currentMeditation.id);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 수정 버튼
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit?.call(_currentMeditation);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCE6E26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '수정',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDropdown() {
    return PopupMenuButton<int>(
      initialValue: _currentIndex,
      onSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_drop_down, size: 24),
            const SizedBox(width: 4),
            Text(
              _buildDateLabel(_currentIndex),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      itemBuilder: (context) {
        // 날짜별로 그룹화
        final dateGroups = <String, List<int>>{};
        for (int i = 0; i < widget.meditations.length; i++) {
          final dateStr = _formatDate(widget.meditations[i].createdAt);
          if (!dateGroups.containsKey(dateStr)) {
            dateGroups[dateStr] = [];
          }
          dateGroups[dateStr]!.add(i);
        }

        return List.generate(widget.meditations.length, (index) {
          return PopupMenuItem<int>(
            value: index,
            child: Text(_buildDateLabel(index)),
          );
        });
      },
    );
  }

  String _buildDateLabel(int index) {
    final meditation = widget.meditations[index];
    final dateStr = _formatDate(meditation.createdAt);

    // 같은 날짜의 묵상들 찾기
    final sameDateMeditations = widget.meditations
        .asMap()
        .entries
        .where((entry) => _formatDate(entry.value.createdAt) == dateStr)
        .toList();

    if (sameDateMeditations.length > 1) {
      // 같은 날짜가 여러 개면 순서 번호 추가
      final orderNumber = sameDateMeditations
          .indexWhere((entry) => entry.key == index) + 1;
      return '$dateStr 묵상($orderNumber)';
    } else {
      // 같은 날짜가 하나면 그냥 날짜만
      return '$dateStr 묵상';
    }
  }

  Widget _buildVerseItem(VerseReference verse) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          verse.displayText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.blue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          verse.text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}