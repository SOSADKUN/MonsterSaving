import '../localization/strings.dart';
import 'dart:convert';

DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
int cents(String value) {
  if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value.trim())) {
    throw FormatException(tr('ledger.001'));
  }
  final p = value.trim().split('.');
  return int.parse(p[0]) * 100 +
      (p.length == 1 ? 0 : int.parse(p[1].padRight(2, '0')));
}

String money(int n) =>
    '${n < 0 ? '-' : ''}RM ${(n.abs() ~/ 100)}.${(n.abs() % 100).toString().padLeft(2, '0')}';

class Entry {
  final String id, date, type, method, description, source, fingerprint;
  final int amount;

  /// This record is already reflected in the balance supplied during setup.
  final bool includedInOpeningBalance;
  final Map<String, dynamic>? importData;
  Entry({
    required this.id,
    required this.date,
    required this.type,
    required this.amount,
    this.includedInOpeningBalance = false,
    this.method = 'Cash',
    this.description = '',
    this.source = 'manual',
    this.fingerprint = '',
    this.importData,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'type': type,
    'amount': amount,
    'method': method,
    'description': description,
    'source': source,
    'fingerprint': fingerprint,
    if (importData != null) 'importData': importData,
    if (includedInOpeningBalance) 'includedInOpeningBalance': true,
  };

  Entry copyWith({bool? includedInOpeningBalance}) => Entry(
    id: id,
    date: date,
    type: type,
    amount: amount,
    method: method,
    description: description,
    source: source,
    fingerprint: fingerprint,
    importData: importData,
    includedInOpeningBalance:
        includedInOpeningBalance ?? this.includedInOpeningBalance,
  );
  factory Entry.fromJson(Map<String, dynamic> j) {
    final e = Entry(
      id: j['id'] as String,
      date: j['date'] as String,
      type: j['type'] as String,
      amount: j['amount'] as int,
      includedInOpeningBalance: j['includedInOpeningBalance'] as bool? ?? false,
      method: j['method'] as String,
      description: j['description'] as String,
      source: j['source'] as String,
      fingerprint: j['fingerprint'] as String,
      importData: j['importData'] == null
          ? null
          : Map<String, dynamic>.from(j['importData']),
    );
    if (e.id.isEmpty ||
        e.amount <= 0 ||
        e.amount > 999999999999 ||
        ![
          'expense',
          'salary',
          'income',
          'refund',
          'adjustment',
        ].contains(e.type) ||
        dateKey(DateTime.parse(e.date)) != e.date) {
      throw FormatException(tr('ledger.002'));
    }
    return e;
  }
}

class Ledger {
  bool hasHatched;
  String language;
  Map<String, dynamic>? profile;
  List<Entry> entries;
  Set<String> achievements, fingerprints, inventory;
  String equipped;
  String background;
  Map<String, int> backgroundPurchases;
  String activeCompanion;
  Set<String> companions;
  Map<String, int> companionPurchases;
  static const companionPrices = {'dinosaur': 100, 'hamster': 100};
  Ledger({
    this.hasHatched = false,
    this.language = 'en',
    this.profile,
    List<Entry>? entries,
    Set<String>? achievements,
    Set<String>? fingerprints,
    Set<String>? inventory,
    this.equipped = '',
    this.background = 'meadow',
    Map<String, int>? backgroundPurchases,
    this.activeCompanion = 'dinosaur',
    Set<String>? companions,
    Map<String, int>? companionPurchases,
  }) : entries = entries ?? [],
       achievements = achievements ?? {},
       fingerprints = fingerprints ?? {},
       inventory = inventory ?? {},
       backgroundPurchases = backgroundPurchases ?? {},
       companions = companions ?? {'dinosaur'},
       companionPurchases = companionPurchases ?? {};
  int get exp => achievements.length * 25;
  int get level => 1 + exp ~/ 100;
  int get stage => ((level - 1) ~/ 3).clamp(0, 3);
  static const prices = {'flower': 20, 'crown': 60, 'bow': 35};
  int get coins =>
      achievements.length * 10 -
      inventory.fold<int>(0, (n, i) => n + (prices[i] ?? 0)) -
      backgroundPurchases.values.fold<int>(0, (total, price) => total + price) -
      companionPurchases.values.fold<int>(0, (total, price) => total + price);
  Map<String, dynamic> toJson() => {
    'hasHatched': hasHatched,
    'language': language,
    'version': 1,
    'profile': profile,
    'entries': entries.map((e) => e.toJson()).toList(),
    'achievements': achievements.toList(),
    'fingerprints': fingerprints.toList(),
    'inventory': inventory.toList(),
    'equipped': equipped,
    'background': background,
    'backgroundPurchases': backgroundPurchases,
    'activeCompanion': activeCompanion,
    'companions': companions.toList(),
    'companionPurchases': companionPurchases,
  };
  Ledger copy() => Ledger.decode(jsonEncode(toJson()));
  factory Ledger.decode(String text) {
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1) {
      throw FormatException(tr('ledger.003'));
    }
    final p = j['profile'] as Map<String, dynamic>?;
    if (p != null) {
      if ((p.containsKey('reminderEnabled') && p['reminderEnabled'] is! bool) ||
          (p.containsKey('reminderMinute') &&
              (p['reminderMinute'] is! int ||
                  p['reminderMinute'] < 0 ||
                  p['reminderMinute'] > 1439))) {
        throw FormatException(tr('ledger.004'));
      }
      if (p.containsKey('recordedDays')) {
        final days = List<String>.from(p['recordedDays']);
        if (days.any((d) => dateKey(DateTime.parse(d)) != d)) {
          throw FormatException(tr('ledger.005'));
        }
      }
      if (p['openingDate'] is! String) {
        throw FormatException(tr('ledger.006'));
      }
      for (final k in ['opening', 'salary', 'target', 'goal', 'saved']) {
        if (p[k] is! int || p[k] < 0 || p[k] > 999999999999) {
          throw FormatException(tr('ledger.007'));
        }
      }
      if (p['payday'] is! int || p['payday'] < 1 || p['payday'] > 31) {
        throw FormatException(tr('ledger.008'));
      }
      for (final k in [
        'openingDate',
        'coverage',
        'lastSalary',
        'savedConfirmedAt',
        'coverageNoticeDismissedFor',
      ]) {
        if (p[k] != null && dateKey(DateTime.parse(p[k])) != p[k]) {
          throw FormatException(tr('ledger.009'));
        }
      }
    }
    final l = Ledger(
      hasHatched: j['hasHatched'] as bool? ?? p != null,
      language: j['language'] as String? ?? 'en',
      profile: p,
      entries: (j['entries'] as List)
          .map((e) => Entry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      achievements: Set<String>.from(j['achievements']),
      fingerprints: Set<String>.from(j['fingerprints']),
      inventory: Set<String>.from(j['inventory']),
      equipped: j['equipped'] as String,
      background: j['background'] as String? ?? 'meadow',
      activeCompanion: j['activeCompanion'] as String? ?? 'dinosaur',
      companions: Set<String>.from(j['companions'] as List? ?? ['dinosaur']),
      companionPurchases: Map<String, int>.from(
        j['companionPurchases'] as Map? ?? const {},
      ),
      backgroundPurchases: Map<String, int>.from(
        j['backgroundPurchases'] as Map? ?? const {},
      ),
    );
    if (l.entries.map((e) => e.id).toSet().length != l.entries.length ||
        !l.companions.contains(l.activeCompanion) ||
        l.companions.any((id) => !companionPrices.containsKey(id)) ||
        l.companionPurchases.entries.any(
          (e) =>
              !l.companions.contains(e.key) || e.value < 0 || e.value > 999999,
        ) ||
        !RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(l.background) ||
        l.backgroundPurchases.entries.any(
          (entry) =>
              !RegExp(r'^[a-z][a-z0-9_-]{0,63}$').hasMatch(entry.key) ||
              entry.value < 0 ||
              entry.value > 999999,
        ) ||
        (l.background != 'meadow' &&
            !l.backgroundPurchases.containsKey(l.background)) ||
        !['en', 'zh_CN'].contains(l.language) ||
        l.entries.any(
          (e) =>
              e.fingerprint.isNotEmpty &&
              !l.fingerprints.contains(e.fingerprint),
        ) ||
        (p == null &&
            (l.entries.isNotEmpty ||
                l.achievements.isNotEmpty ||
                l.inventory.isNotEmpty ||
                l.companionPurchases.isNotEmpty ||
                l.backgroundPurchases.isNotEmpty ||
                l.background != 'meadow')) ||
        l.achievements.any(
          (a) =>
              !RegExp(r'^record:\d{4}-\d{2}-\d{2}$').hasMatch(a) ||
              dateKey(DateTime.parse(a.substring(7))) != a.substring(7),
        ) ||
        l.entries
                .where((e) => e.fingerprint.isNotEmpty)
                .map((e) => e.fingerprint)
                .toSet()
                .length !=
            l.entries.where((e) => e.fingerprint.isNotEmpty).length ||
        l.inventory.any((i) => !prices.containsKey(i)) ||
        l.coins < 0 ||
        (l.equipped.isNotEmpty && !l.inventory.contains(l.equipped))) {
      throw FormatException(tr('ledger.010'));
    }
    return l;
  }
}
