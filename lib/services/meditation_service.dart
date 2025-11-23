import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/meditation.dart';

class MeditationService {
  // 싱글톤 패턴
  static final MeditationService _instance = MeditationService._internal();
  factory MeditationService() => _instance;
  MeditationService._internal();

  static const String _storageKey = 'meditations';
  final Map<String, List<Meditation>> _meditationsCache = {}; // userId별 캐시

  // 사용자의 모든 묵상 가져오기
  Future<List<Meditation>> getMeditations(String userId) async {
    // 캐시 확인
    if (_meditationsCache.containsKey(userId)) {
      return _meditationsCache[userId]!;
    }

    // SharedPreferences에서 로드
    final prefs = await SharedPreferences.getInstance();
    final meditationsJson = prefs.getStringList('${_storageKey}_$userId') ?? [];

    final meditations = meditationsJson
        .map((json) => Meditation.fromJson(jsonDecode(json)))
        .toList();

    _meditationsCache[userId] = meditations;
    return meditations;
  }

  // 특정 구절의 묵상들 가져오기
  Future<List<Meditation>> getMeditationsByVerse(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    final allMeditations = await getMeditations(userId);

    return allMeditations.where((meditation) {
      return meditation.verses.any((v) =>
      v.book == book && v.chapter == chapter && v.verse == verse);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // 최신순 정렬
  }

  // 묵상 저장
  Future<void> saveMeditation(Meditation meditation) async {
    final meditations = await getMeditations(meditation.userId);

    // 기존 묵상 찾기
    final index = meditations.indexWhere((m) => m.id == meditation.id);

    if (index >= 0) {
      // 기존 묵상 업데이트
      meditations[index] = meditation;
    } else {
      // 새 묵상 추가
      meditations.add(meditation);
    }

    // SharedPreferences에 저장
    await _saveMeditations(meditation.userId, meditations);

    // 캐시 업데이트
    _meditationsCache[meditation.userId] = meditations;
  }

  // 묵상 삭제
  Future<void> deleteMeditation(String userId, String meditationId) async {
    final meditations = await getMeditations(userId);
    meditations.removeWhere((m) => m.id == meditationId);

    await _saveMeditations(userId, meditations);
    _meditationsCache[userId] = meditations;
  }

  // SharedPreferences에 저장
  Future<void> _saveMeditations(String userId, List<Meditation> meditations) async {
    final prefs = await SharedPreferences.getInstance();
    final meditationsJson = meditations
        .map((m) => jsonEncode(m.toJson()))
        .toList();

    await prefs.setStringList('${_storageKey}_$userId', meditationsJson);
  }

  // 특정 구절이 하이라이트되어 있는지 확인
  Future<String?> getVerseHighlightColor(
      String userId,
      String book,
      int chapter,
      int verse,
      ) async {
    final meditations = await getMeditationsByVerse(userId, book, chapter, verse);

    if (meditations.isEmpty) return null;

    // 가장 최근 묵상의 하이라이트 색상 반환
    return meditations.first.highlightColor;
  }

  // 묵상 ID 생성
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // 캐시 클리어
  void clearCache() {
    _meditationsCache.clear();
  }
}