// lib/services/bible_service.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:excel/excel.dart';

///==============================================================
/// 1) Excel 관련 기능 (원래 excel_service.dart 역할)
///==============================================================

/// assets/script.xlsx 파일을 로드해서 Excel 객체를 반환합니다.
Future<Excel?> loadExcel() async {
  try {
    if (kDebugMode) {
      print("🔍 [excel_service] loadExcel() called...");
    }
    ByteData data = await rootBundle.load("assets/script.xlsx");
    var bytes = data.buffer.asUint8List();
    var excel = Excel.decodeBytes(bytes);
    if (kDebugMode) {
      print("✅ [excel_service] script.xlsx 로드 성공, sheet 수: ${excel.tables.keys.length}");
    }
    return excel;
  } catch (e) {
    if (kDebugMode) {
      print("❌ [excel_service] script.xlsx 로딩 오류: $e");
    }
    return null;
  }
}

/// 지정한 시트(sheetName)의 모든 행 데이터를 2차원 리스트로 반환합니다.
Future<List<List<String>>> readSheetData(String sheetName) async {
  var excel = await loadExcel();
  if (excel == null) return [];
  // sheet는 null이 아님을 보장
  Sheet sheet = excel[sheetName]!;
  List<List<String>> rows = [];
  for (var rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
    List<Data?> row = sheet.row(rowIndex);
    List<String> values = row.map((cell) => cell?.value?.toString() ?? "").toList();
    rows.add(values);
  }
  if (kDebugMode) {
    print("✅ [excel_service] readSheetData($sheetName) - total rows read: ${rows.length}");
  }
  return rows;
}

/// 첫 번째 행을 헤더로 하여 데이터를 Map 리스트로 파싱합니다.
Future<List<Map<String, dynamic>>> readSheetDataAsMaps(String sheetName) async {
  final rows = await readSheetData(sheetName);
  List<Map<String, dynamic>> data = [];
  if (rows.isNotEmpty) {
    List<String> headers = rows.first;
    for (int i = 1; i < rows.length; i++) {
      var row = rows[i];
      if (row.isEmpty) continue;
      Map<String, dynamic> map = {};
      for (int j = 0; j < headers.length && j < row.length; j++) {
        map[headers[j]] = row[j];
      }
      data.add(map);
    }
  }
  if (kDebugMode) {
    print("✅ [excel_service] readSheetDataAsMaps($sheetName) - total mapped rows: ${data.length}");
  }
  return data;
}

/// (연도 무시) 날짜(월-일)가 일치하는 행들만 반환합니다.
/// 예: "2025-03-05" -> month=3, day=5
Future<List<Map<String, dynamic>>> fetchTodayBibleRows(
    String sheetName, DateTime selectedDate) async {
  final rows = await readSheetDataAsMaps(sheetName);
  int selMonth = selectedDate.month;
  int selDay = selectedDate.day;
  List<Map<String, dynamic>> results = [];
  if (kDebugMode) {
    print("🔍 [excel_service] fetchTodayBibleRows($sheetName), selMonth=$selMonth, selDay=$selDay, totalRows=${rows.length}");
  }
  for (var row in rows) {
    if (row.containsKey("Date") && row["Date"] is String) {
      String dateString = row["Date"];
      List<String> parts = dateString.split("-");
      if (parts.length == 3) {
        int month = int.tryParse(parts[1]) ?? 0;
        int day = int.tryParse(parts[2]) ?? 0;
        if (month == selMonth && day == selDay) {
          results.add(row);
        }
      } else if (parts.length == 2) {
        int month = int.tryParse(parts[0]) ?? 0;
        int day = int.tryParse(parts[1]) ?? 0;
        if (month == selMonth && day == selDay) {
          results.add(row);
        }
      }
    }
  }
  if (kDebugMode) {
    print("✅ [excel_service] fetchTodayBibleRows($sheetName) - found ${results.length} matched rows");
    for (var r in results) {
      print("   -> $r");
    }
  }
  return results;
}

///==============================================================
/// 2) 성경 JSON 로딩 + 구절 빌드 (원래 bible_service.dart 역할)
///==============================================================

/// 영어 성경 책 이름 변환용 맵 (엑셀의 Book이 한글 한 글자일 때 -> 영어 약어)
const Map<String, String> englishBibleBooks = {
  "창": "Gen",
  "출": "Exod",
  "레": "Lev",
  "민": "Num",
  "신": "Deut",
  // ... 필요 시 추가
};

/// (A) 한글 성경 JSON 파일 로드
Future<Map<String, dynamic>> loadBibleJsonKr() async {
  try {
    if (kDebugMode) {
      print("📖 [bible_service] bible.json (KR) 로딩 중...");
    }
    final jsonString = await rootBundle.loadString("assets/bible.json");
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    if (kDebugMode) {
      print("✅ [bible_service] bible.json (KR) 로드 완료!");
    }
    return jsonData;
  } catch (e) {
    if (kDebugMode) {
      print("❌ [bible_service] bible.json (KR) 로딩 오류: $e");
    }
    return {};
  }
}

/// (B) 영어 성경 JSON 파일 로드
Future<Map<String, dynamic>> loadBibleJsonEn() async {
  try {
    if (kDebugMode) {
      print("📖 [bible_service] bible_esv.json (EN) 로딩 중...");
    }
    final jsonString = await rootBundle.loadString("assets/bible_esv.json");
    final Map<String, dynamic> jsonData = jsonDecode(jsonString);
    if (kDebugMode) {
      print("✅ [bible_service] bible_esv.json (EN) 로드 완료!");
    }
    return jsonData;
  } catch (e) {
    if (kDebugMode) {
      print("❌ [bible_service] bible_esv.json (EN) 로딩 오류: $e");
    }
    return {};
  }
}

///==============================================================
/// 3) 구절 빌드 로직 (KR, EN, Compare)
///==============================================================

/// (A) 한글 모드
Map<String, List<Widget>> buildVerseWidgetsKr(
    List<Map<String, dynamic>> bibleInfos,
    Map<String, dynamic> bibleDataKr,
    ) {
  final Map<String, List<Widget>> groupMap = {};
  for (var info in bibleInfos) {
    // 예: {Date: 2025-03-05, Book: 레, Book(ENG): Lev, Start Chapter: 27.0, End Chapter: 27.0, Full Name: 레위기, ...}
    String bookAbbrev = (info["Book"] as String?)?.trim() ?? "";
    String fullName = (info["Full Name"] as String?)?.trim() ?? "";
    int startChapter = (double.tryParse(info["Start Chapter"]?.toString() ?? "") ?? 1).toInt();
    int endChapter = (double.tryParse(info["End Chapter"]?.toString() ?? "") ?? startChapter).toInt();
    if (endChapter < startChapter) endChapter = startChapter;
    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      String groupKey = "$fullName $chapter장(개역개정)";
      groupMap.putIfAbsent(groupKey, () => []);
      if (groupMap[groupKey]!.isEmpty) {
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                groupKey,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
      int verseNum = 1;
      while (true) {
        String key = "$bookAbbrev$chapter:$verseNum";
        if (!bibleDataKr.containsKey(key)) break;
        String verseText = bibleDataKr[key].toString().trim();
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 24.0),
            child: Text(
              "$verseNum. $verseText",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
        verseNum++;
      }
    }
  }
  if (kDebugMode) {
    print("✅ [bible_service] buildVerseWidgetsKr: 총 ${groupMap.length}개 장 그룹");
  }
  return groupMap;
}

/// (B) 영어 모드
Map<String, List<Widget>> buildVerseWidgetsEn(
    List<Map<String, dynamic>> bibleInfos,
    Map<String, dynamic> bibleDataEn,
    ) {
  final Map<String, List<Widget>> groupMap = {};
  for (var info in bibleInfos) {
    String bookAbbrevEn = (info["Book(ENG)"] as String?)?.trim() ?? "";
    String fullNameEn = (info["Full Name(ENG)"] as String?)?.trim() ?? "";
    if (bookAbbrevEn.isEmpty) {
      String bookKr = (info["Book"] as String?)?.trim() ?? "";
      bookAbbrevEn = englishBibleBooks[bookKr] ?? bookKr;
    }
    int startChapter = (double.tryParse(info["Start Chapter"]?.toString() ?? "") ?? 1).toInt();
    int endChapter = (double.tryParse(info["End Chapter"]?.toString() ?? "") ?? startChapter).toInt();
    if (endChapter < startChapter) endChapter = startChapter;
    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      String groupKey = fullNameEn.isNotEmpty ? "$fullNameEn $chapter(ESV)" : "$bookAbbrevEn $chapter";
      groupMap.putIfAbsent(groupKey, () => []);
      if (groupMap[groupKey]!.isEmpty) {
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                groupKey,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
      int verseNum = 1;
      while (true) {
        String key = "$bookAbbrevEn$chapter:$verseNum";
        if (!bibleDataEn.containsKey(key)) break;
        String verseText = bibleDataEn[key].toString().trim();
        verseText = verseText.replaceAll(r'\\"', '"').replaceAll(r'\"', '"');
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 24.0),
            child: Text(
              "$verseNum. $verseText",
              style: const TextStyle(fontSize: 16),
            ),
          ),
        );
        verseNum++;
      }
    }
  }
  if (kDebugMode) {
    print("✅ [bible_service] buildVerseWidgetsEn: 총 ${groupMap.length}개 장 그룹");
  }
  return groupMap;
}

/// (C) 한영대조 모드
/// 한영대조 모드에서는 한글 구절은 번호+본문, 영어 구절은 본문만 표시합니다.
Map<String, List<Widget>> buildVerseWidgetsCompare(
    List<Map<String, dynamic>> bibleInfos,
    Map<String, dynamic> bibleDataKr,
    Map<String, dynamic> bibleDataEn,
    ) {
  final Map<String, List<Widget>> groupMap = {};
  for (var info in bibleInfos) {
    String bookKr = (info["Book"] as String?)?.trim() ?? "";
    String bookEn = (info["Book(ENG)"] as String?)?.trim() ?? "";
    String fullNameKr = (info["Full Name"] as String?)?.trim() ?? "";
    String fullNameEn = (info["Full Name(ENG)"] as String?)?.trim() ?? "";
    if (bookEn.isEmpty) {
      bookEn = englishBibleBooks[bookKr] ?? bookKr;
    }
    int startChapter = (double.tryParse(info["Start Chapter"]?.toString() ?? "") ?? 1).toInt();
    int endChapter = (double.tryParse(info["End Chapter"]?.toString() ?? "") ?? startChapter).toInt();
    if (endChapter < startChapter) endChapter = startChapter;
    for (int chapter = startChapter; chapter <= endChapter; chapter++) {
      String groupKey = "$fullNameKr $chapter장(한영대조)";
      groupMap.putIfAbsent(groupKey, () => []);
      if (groupMap[groupKey]!.isEmpty) {
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Center(
              child: Text(
                groupKey,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }
      int verseNum = 1;
      while (true) {
        String keyKr = "$bookKr$chapter:$verseNum";
        if (!bibleDataKr.containsKey(keyKr)) break;
        String verseKr = bibleDataKr[keyKr].toString().trim();
        String keyEn = "$bookEn$chapter:$verseNum";
        String verseEn = bibleDataEn.containsKey(keyEn)
            ? bibleDataEn[keyEn].toString().trim()
            : "(영문 본문 없음)";
        verseEn = verseEn.replaceAll(r'\\"', '"').replaceAll(r'\"', '"');
        // 한글은 번호+본문, 영어는 본문만 표시
        groupMap[groupKey]!.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$verseNum. $verseKr",
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                Text(
                  verseEn,
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ],
            ),
          ),
        );
        verseNum++;
      }
    }
  }
  if (kDebugMode) {
    print("✅ [bible_service] buildVerseWidgetsCompare: 총 ${groupMap.length}개 장 그룹");
  }
  return groupMap;
}

///==============================================================
/// 4) 최종: loadGroupedBibleVerseWidgets
///    (시트명, 날짜, 언어 모드) -> Future<맵<장제목, 위젯목록>>
///==============================================================
Future<Map<String, List<Widget>>> loadGroupedBibleVerseWidgets(
    String sheetName,
    DateTime selectedDate,
    BuildContext context, {
      String language = "kr", // "kr", "en", "compare"
    }) async {
  try {
    if (kDebugMode) {
      print("📖 loadGroupedBibleVerseWidgets 실행됨: $sheetName, 날짜: $selectedDate, 언어: $language");
    }
    // 1) 엑셀에서 오늘 읽을 구간(rows) 가져오기
    final bibleInfos = await fetchTodayBibleRows(sheetName, selectedDate);
    if (bibleInfos.isEmpty) {
      if (kDebugMode) {
        print("⚠️ 오늘 날짜($selectedDate)에 해당하는 엑셀 데이터 없음");
      }
      return {};
    }
    if (kDebugMode) {
      print("✅ 오늘의 성경 본문 개수: ${bibleInfos.length}");
      for (var r in bibleInfos) {
        print("   -> $r");
      }
    }
    // 2) JSON 로딩
    final bibleDataKr = await loadBibleJsonKr();
    final bibleDataEn = await loadBibleJsonEn();
    // 3) language 모드별로 구절 빌드
    if (language == "kr") {
      return buildVerseWidgetsKr(bibleInfos, bibleDataKr);
    } else if (language == "en") {
      return buildVerseWidgetsEn(bibleInfos, bibleDataEn);
    } else {
      return buildVerseWidgetsCompare(bibleInfos, bibleDataKr, bibleDataEn);
    }
  } catch (e, st) {
    if (kDebugMode) {
      print("❌ loadGroupedBibleVerseWidgets 오류: $e\n$st");
    }
    return {};
  }
}
