class VacationBalance {
  const VacationBalance({
    required this.annual,
    required this.used,
    required this.remaining,
    required this.year,
  });

  final int annual;
  final int used;
  final int remaining;
  final int year;

  factory VacationBalance.fromJson(Map<String, dynamic> json) {
    return VacationBalance(
      annual: json['annual'] as int,
      used: json['used'] as int,
      remaining: json['remaining'] as int,
      year: json['year'] as int,
    );
  }
}

int countVacationDays(DateTime start, DateTime end) {
  var count = 0;
  for (var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)) {
    if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
      count++;
    }
  }
  return count;
}
