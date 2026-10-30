import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/state.dart';
import '../../app/widgets.dart';
import '../../core/localization/context.dart';
import '../monster/background_catalog.dart';

class BackgroundShop extends ConsumerWidget {
  const BackgroundShop({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider).requireValue;
    return FutureBuilder<List<HabitatBackground>>(
      future: BackgroundCatalog.load(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(context.tr('background.unavailable'));
        }
        final backgrounds = snapshot.data;
        if (backgrounds == null) return const SizedBox(height: 16);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('background.title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (backgrounds.length == 1)
              Text(context.tr('background.comingSoon')),
            for (final background in backgrounds)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: HabitatBackdrop(background: background),
                    ),
                  ),
                  title: Text(background.name),
                  subtitle: Text(
                    background.price == 0
                        ? context.tr('background.free')
                        : context.tr('shop.006', {'p0': background.price}),
                  ),
                  trailing: FilledButton(
                    onPressed:
                        ledger.background == background.id ||
                            (!ledger.backgroundPurchases.containsKey(
                                  background.id,
                                ) &&
                                background.id != 'meadow' &&
                                ledger.coins < background.price)
                        ? null
                        : () async {
                            try {
                              await ref.read(ledgerProvider.notifier).change((
                                state,
                              ) {
                                if (background.id != 'meadow' &&
                                    !state.backgroundPurchases.containsKey(
                                      background.id,
                                    )) {
                                  if (state.coins < background.price) {
                                    throw StateError(context.tr('shop.007'));
                                  }
                                  // Store the paid price so later catalog edits never
                                  // retroactively change a player's spent coins.
                                  state.backgroundPurchases[background.id] =
                                      background.price;
                                }
                                state.background = background.id;
                              });
                            } catch (error) {
                              if (context.mounted) notice(context, error);
                            }
                          },
                    child: Text(
                      ledger.background == background.id
                          ? context.tr('background.current')
                          : ledger.backgroundPurchases.containsKey(
                                  background.id,
                                ) ||
                                background.id == 'meadow' ||
                                background.price == 0
                          ? context.tr('background.use')
                          : context.tr('shop.010'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
