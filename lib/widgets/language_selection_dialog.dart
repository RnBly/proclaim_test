import 'package:flutter/material.dart';
import '../models/language_mode.dart';

class LanguageSelectionDialog extends StatelessWidget {
  final Function(LanguageMode) onLanguageSelected;

  const LanguageSelectionDialog({super.key, required this.onLanguageSelected});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("언어 선택"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text("개역개정"),
            onTap: () => onLanguageSelected(LanguageMode.korean),
          ),
          ListTile(
            title: const Text("ESV"),
            onTap: () => onLanguageSelected(LanguageMode.english),
          ),
          ListTile(
            title: const Text("한영 비교"),
            onTap: () => onLanguageSelected(LanguageMode.compare),
          ),
        ],
      ),
    );
  }
}
