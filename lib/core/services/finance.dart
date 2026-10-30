import '../models/ledger.dart';

class Finance {
  final DateTime start, end;
  final int balance, income, spending, reserve, remainingDays;
  Finance(
    this.start,
    this.end,
    this.balance,
    this.income,
    this.spending,
    this.reserve,
    this.remainingDays,
  );
  int get available => balance - reserve;
  int get daily => available >= 0
      ? available ~/ remainingDays
      : -((-available + remainingDays - 1) ~/ remainingDays);
  static DateTime payday(int y, int m, int p) =>
      DateTime(y, m, p.clamp(1, DateTime(y, m + 1, 0).day));
  factory Finance.calculate(Ledger l, DateTime now) {
    final p = l.profile!;
    final today = day(now);
    final pay = p['payday'] as int;
    final thisPay = payday(today.year, today.month, pay);
    final start = today.isBefore(thisPay)
        ? payday(today.year, today.month - 1, pay)
        : thisPay;
    final end = payday(start.year, start.month + 1, pay);
    int balance = p['opening'], income = 0, spending = 0;
    for (final e in l.entries) {
      final d = DateTime.parse(e.date);
      if (d.isAfter(today)) {
        continue;
      }
      if (!e.includedInOpeningBalance &&
          !d.isBefore(DateTime.parse(p['openingDate']))) {
        balance += e.type == 'expense' ? -e.amount : e.amount;
      }
      if (!d.isBefore(start) && d.isBefore(end)) {
        if (e.type == 'expense') {
          spending += e.amount;
        }
        if (e.type == 'income' || e.type == 'salary') {
          income += e.amount;
        }
      }
    }
    // Opening cash funds the reservation too. Confirmed savings is a subset
    // of this balance, not an additional expense or a second cash account.
    final reserve = (p['target'] as int) > (p['saved'] as int)
        ? p['target'] as int
        : p['saved'] as int;
    final days = DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return Finance(start, end, balance, income, spending, reserve, days);
  }
}
