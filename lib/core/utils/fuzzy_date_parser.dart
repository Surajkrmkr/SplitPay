/// Best-effort date/time extraction from free-form text (bill OCR lines,
/// SMS bodies, etc). Shared so every "read a date out of noisy text" caller
/// — bill scanning, SMS parsing — agrees on the same set of formats.
library;

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'sept': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
  'january': 1,
  'february': 2,
  'march': 3,
  'april': 4,
  'june': 6,
  'july': 7,
  'august': 8,
  'september': 9,
  'october': 10,
  'november': 11,
  'december': 12,
};

/// Walks [lines] in order and returns the date + time combined, if both are
/// found (date-only if no time is present, null if no date is found).
DateTime? extractDateTimeFromLines(List<String> lines) {
  final date = extractDateFromLines(lines);
  if (date == null) return null;
  final time = extractTimeFromLines(lines);
  if (time == null) return date;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

DateTime? extractDateFromLines(List<String> lines) {
  final monthRe = _months.keys.join('|');
  final numericRe = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b');
  // Separator between day/month-name/year can be a space OR a hyphen — bank
  // SMS commonly write "01-Jan-24" while OCR'd bills use "01 Jan 2024".
  final dmyRe = RegExp(
      r'\b(\d{1,2})[\s\-]+(' + monthRe + r')\.?[\s\-]+(\d{2,4})\b',
      caseSensitive: false);
  final mdyRe = RegExp(
      r'\b(' + monthRe + r')\.?[\s\-]+(\d{1,2}),?[\s\-]+(\d{2,4})\b',
      caseSensitive: false);

  // First plausible date wins — for bills that means top-to-bottom order;
  // for a single SMS body it's just whichever match comes first in text.
  for (final line in lines) {
    for (final m in numericRe.allMatches(line)) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      var y = int.tryParse(m.group(3)!);
      if (d == null || mo == null || y == null) continue;
      if (y < 100) y += 2000;

      // Assume DD/MM (Indian convention); swap if month > 12.
      var day = d, month = mo;
      if (month > 12 && day <= 12) {
        day = mo;
        month = d;
      }
      try {
        final dt = DateTime(y, month, day);
        if (dt.year < 2000) continue;
        if (dt.isAfter(DateTime.now().add(const Duration(days: 1)))) continue;
        return dt;
      } catch (_) {}
    }

    for (final m in dmyRe.allMatches(line)) {
      final d = int.tryParse(m.group(1)!);
      final mo = _months[m.group(2)!.toLowerCase()];
      var y = int.tryParse(m.group(3)!);
      if (d == null || mo == null || y == null) continue;
      if (y < 100) y += 2000;
      try {
        return DateTime(y, mo, d);
      } catch (_) {}
    }

    for (final m in mdyRe.allMatches(line)) {
      final mo = _months[m.group(1)!.toLowerCase()];
      final d = int.tryParse(m.group(2)!);
      var y = int.tryParse(m.group(3)!);
      if (d == null || mo == null || y == null) continue;
      if (y < 100) y += 2000;
      try {
        return DateTime(y, mo, d);
      } catch (_) {}
    }
  }

  return null;
}

({int hour, int minute})? extractTimeFromLines(List<String> lines) {
  final re = RegExp(r'\b(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\b');

  for (final line in lines) {
    final lower = line.toLowerCase();
    // Skip lines that almost never carry a real time: bill/invoice/order
    // numbers, KOT, table — the digits there are IDs, not clocks.
    if (lower.contains('bill no') ||
        lower.contains('invoice no') ||
        lower.contains('order no') ||
        lower.contains('order id') ||
        lower.contains('kot') ||
        lower.contains('table')) {
      continue;
    }

    for (final m in re.allMatches(line)) {
      final h = int.tryParse(m.group(1)!);
      final mn = int.tryParse(m.group(2)!);
      if (h == null || mn == null) continue;
      if (mn < 0 || mn > 59) continue;

      var hour = h;
      final suffix = m.group(3)?.toLowerCase();
      if (suffix != null) {
        if (hour < 1 || hour > 12) continue;
        if (suffix.startsWith('p') && hour < 12) hour += 12;
        if (suffix.startsWith('a') && hour == 12) hour = 0;
      } else {
        if (hour > 23) continue;
      }
      return (hour: hour, minute: mn);
    }
  }
  return null;
}
