// lib/utils/date_formatter.dart

import 'package:intl/intl.dart';

String formatToday(DateTime date) {
  String month = DateFormat.MMM().format(date);
  int day = date.day;
  String suffix = getOrdinalSuffix(day);
  return "$month, $day$suffix";
}

String getOrdinalSuffix(int day) {
  if (day >= 11 && day <= 13) return "th";
  switch (day % 10) {
    case 1: return "st";
    case 2: return "nd";
    case 3: return "rd";
    default: return "th";
  }
}
