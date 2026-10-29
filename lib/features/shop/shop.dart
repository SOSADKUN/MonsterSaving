import '../../core/localization/context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/models/ledger.dart';

class ShopPanel extends ConsumerWidget {
  const ShopPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(ledgerProvider).requireValue;
    return Column(
      children: [
        Text(
          context.tr('shop.001', {'p0': l.coins}),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(context.tr('shop.002')),
        for (final item in Ledger.prices.entries)
          Card(
            child: ListTile(
              title: Text(
                {
                  'flower': context.tr('shop.003'),
                  'crown': context.tr('shop.004'),
                  'bow': context.tr('shop.005'),
                }[item.key]!,
              ),
              subtitle: Text(context.tr('shop.006', {'p0': item.value})),
              trailing: FilledButton(
                onPressed:
                    (!l.inventory.contains(item.key) && l.coins < item.value)
                    ? null
                    : () async {
                        try {
                          await ref.read(ledgerProvider.notifier).change((s) {
                            if (!s.inventory.contains(item.key)) {
                              if (s.coins < item.value) {
                                throw StateError(context.tr('shop.007'));
                              }
                              s.inventory.add(item.key);
                            }
                            s.equipped = s.equipped == item.key ? '' : item.key;
                          });
                        } catch (e) {
                          if (context.mounted) {
                            notice(context, e);
                          }
                        }
                      },
                child: Text(
                  l.equipped == item.key
                      ? context.tr('shop.008')
                      : l.inventory.contains(item.key)
                      ? context.tr('shop.009')
                      : context.tr('shop.010'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
