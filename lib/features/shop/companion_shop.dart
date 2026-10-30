import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/localization/context.dart';
import '../../core/models/ledger.dart';
import '../monster/companion_catalog.dart';

class CompanionShop extends ConsumerStatefulWidget {
  const CompanionShop({super.key});

  @override
  ConsumerState<CompanionShop> createState() => _CompanionShopState();
}

class _CompanionShopState extends ConsumerState<CompanionShop> {
  bool _saving = false;

  Future<void> _select(String id) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(ledgerProvider.notifier).change((ledger) {
        if (!ledger.companions.contains(id)) {
          final price = Ledger.companionPrices[id]!;
          if (ledger.coins < price) {
            throw StateError(context.tr('shop.007'));
          }
          ledger.companionPurchases[id] = price;
          ledger.companions.add(id);
        }
        ledger.activeCompanion = id;
      });
    } catch (error) {
      if (mounted) notice(context, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(ledgerProvider).requireValue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('companions.title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final item in Ledger.companionPrices.entries)
          Builder(
            builder: (context) {
              final owned = ledger.companions.contains(item.key);
              final active = ledger.activeCompanion == item.key;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 88,
                        height: 110,
                        child: CompanionPortrait(companion: item.key),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('companions.${item.key}'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              owned
                                  ? context.tr('companions.owned')
                                  : context.tr('shop.006', {'p0': item.value}),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed:
                                  _saving ||
                                      active ||
                                      (!owned && ledger.coins < item.value)
                                  ? null
                                  : () => _select(item.key),
                              child: Text(
                                context.tr(
                                  active
                                      ? 'companions.active'
                                      : owned
                                      ? 'companions.choose'
                                      : 'companions.buy',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
