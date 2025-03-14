import 'package:flutter/material.dart';

class NavigationControls extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const NavigationControls({
    super.key,
    required this.pageController,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: currentPage == 0 ? Colors.grey[300] : null,
          ),
          onPressed: currentPage == 0
              ? null
              : () {
            pageController.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            onPageChanged(currentPage - 1);
          },
        ),
        IconButton(
          icon: Icon(
            Icons.arrow_forward,
            color: currentPage == totalPages - 1 ? Colors.grey[300] : null,
          ),
          onPressed: currentPage == totalPages - 1
              ? null
              : () {
            pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            onPageChanged(currentPage + 1);
          },
        ),
      ],
    );
  }
}
