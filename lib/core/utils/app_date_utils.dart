import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum DateRangeFilter {
  today,
  thisWeek,
  thisMonth,
  last6Months,
  thisYear,
  last3Years,
  custom,
}

extension DateRangeFilterExtension on DateRangeFilter {
  String get label {
    switch (this) {
      case DateRangeFilter.today:
        return 'Today';
      case DateRangeFilter.thisWeek:
        return 'This Week';
      case DateRangeFilter.thisMonth:
        return 'This Month';
      case DateRangeFilter.last6Months:
        return 'Last 6 Months';
      case DateRangeFilter.thisYear:
        return 'This Year';
      case DateRangeFilter.last3Years:
        return 'Last 3 Years';
      case DateRangeFilter.custom:
        return 'Custom Range';
    }
  }
}

class AppDateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMM yyyy').format(date);
  }

  static String formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) {
      return 'Today';
    } else if (checkDate == yesterday) {
      return 'Yesterday';
    } else if (date.year == now.year) {
      return DateFormat('EEEE, MMM d').format(date);
    } else {
      return DateFormat('EEEE, MMM d, yyyy').format(date);
    }
  }

  /// Calculates DateTimeRange based on the chosen filter.
  static DateTimeRange getRangeForFilter(DateRangeFilter filter, {DateTimeRange? customRange}) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (filter) {
      case DateRangeFilter.today:
        return DateTimeRange(start: todayStart, end: todayEnd);

      case DateRangeFilter.thisWeek:
        final startOfWeek = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        return DateTimeRange(start: startOfWeek, end: todayEnd);

      case DateRangeFilter.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: startOfMonth, end: endOfMonth);

      case DateRangeFilter.last6Months:
        final start6MonthsAgo = DateTime(now.year, now.month - 5, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start6MonthsAgo, end: endOfMonth);

      case DateRangeFilter.thisYear:
        final startOfYear = DateTime(now.year, 1, 1);
        final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: startOfYear, end: endOfYear);

      case DateRangeFilter.last3Years:
        final start3YearsAgo = DateTime(now.year - 2, 1, 1);
        final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start3YearsAgo, end: endOfYear);

      case DateRangeFilter.custom:
        if (customRange != null) {
          final customStart = DateTime(customRange.start.year, customRange.start.month, customRange.start.day);
          final customEnd = DateTime(customRange.end.year, customRange.end.month, customRange.end.day, 23, 59, 59, 999);
          return DateTimeRange(start: customStart, end: customEnd);
        }
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: todayEnd);
    }
  }

  /// Checks if a date falls within a DateTimeRange inclusive.
  static bool isDateInRange(DateTime date, DateTimeRange range) {
    return (date.isAfter(range.start) || date.isAtSameMomentAs(range.start)) &&
        (date.isBefore(range.end) || date.isAtSameMomentAs(range.end));
  }
}
