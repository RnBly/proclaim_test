// lib/dialogs/date_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateSelectionDialog extends StatefulWidget {
  final DateTime initialDate;
  const DateSelectionDialog({super.key, required this.initialDate});

  @override
  State<DateSelectionDialog> createState() => _DateSelectionDialogState();
}

class _DateSelectionDialogState extends State<DateSelectionDialog> {
  late FixedExtentScrollController _controller;
  final int baseIndex = 100000; // 무한 스크롤을 위한 기준값
  int _selectedIndex = 100000;

  @override
  void initState() {
    super.initState();
    _selectedIndex = baseIndex;
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16.0),
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            // 상단 X 버튼
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              ],
            ),
            Expanded(
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 50,
                diameterRatio: 2,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) {
                    DateTime date = widget.initialDate.add(Duration(days: index - baseIndex));
                    int distance = (index - _selectedIndex).abs();
                    double fontSize = 24 - (distance * 2);
                    double opacity = 1 - (distance * 0.3);
                    return GestureDetector(
                      onTap: () {
                        if (index != _selectedIndex) {
                          _controller.animateToItem(
                            index,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          Navigator.pop(context, date);
                        }
                      },
                      child: Opacity(
                        opacity: opacity.clamp(0.3, 1.0),
                        child: Center(
                          child: Text(
                            DateFormat('EEE, MMM d').format(date),
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: index == _selectedIndex ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: 1000000,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
