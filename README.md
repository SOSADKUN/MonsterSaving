# Saving Monster · 存钱小怪兽

Flutter stable / Dart app, version **0.0.1+1**, Android + iOS + Web.
Validated SDK: Flutter 3.41.9 stable, Dart 3.11.5. Dependencies are pinned by pubspec.lock.

## Run

Put the Flutter SDK on PATH, then:

```sh
flutter pub get
flutter run -d chrome --web-header=Cross-Origin-Opener-Policy=same-origin --web-header=Cross-Origin-Embedder-Policy=require-corp
flutter run -d <android-device-id>
# macOS with Xcode, CocoaPods and an iOS simulator/device:
flutter run -d <ios-device-id>
```

```sh
dart run build_runner build
flutter analyze
flutter test
dart run tool/build_web.dart
flutter build apk --release
# macOS only:
flutter build ios --release --no-codesign
```

Serve build/web over HTTPS (localhost also works), with application/wasm for sqlite3.wasm, Cross-Origin-Opener-Policy: same-origin and Cross-Origin-Embedder-Policy: require-corp. web/_headers supplies these for hosts that support that file; other hosts require equivalent server configuration. SQLite WASM and worker are bundled from official Drift 2.34.4 release assets. Upgrade both together with Drift. In-memory and unsafe multi-tab storage fallbacks are rejected rather than silently losing financial records. The app uses no backend or analytics. The bundled Noto Sans SC font includes its OFL license. Initial Web installation requires network; cached offline operation and browser storage retention need browser/device acceptance testing. tool/build_web.dart builds Flutter with locally bundled renderer resources, then generates a versioned service worker that precaches all Web assets. Use this command for deployable offline bundles; a plain flutter build web output requires the post-build cache step.

## Implemented

- Six-step guest onboarding with supplied local loading/intro videos and a reference-sprite Flame baby reveal, financial setup, pending initial expense entry, daily TNG import, and tutorial. Profile and initial entries commit together.
- Official-reference sprite-based Flame Baby Monster: idle movement, blinks, tap reaction, financial mood, four evolution stages and three visible cosmetics.
- Integer-cent ledger, clamped calendar payday cycles, confirmed salary/extra income, expenses/refunds, daily/cycle budget, coverage confirmation, history/edit/delete.
- Persistent EXP and coins: 25 EXP and 10 coins for each distinct transaction date first recorded. Reward tombstones survive edits/deletions. Shop inventory and equipment persist.
- Salary/goal settings, explicit savings confirmation, JSON export/validated atomic restore, reset confirmation.
- Responsive Material 3 English / Simplified Chinese UI, loading/errors, local SQLite via Drift, schema version 1, optimistic stale-write rejection. No fake account sessions.

## Financial conventions

The opening balance is a snapshot **at the start of the selected local date**. Only enter transactions not already represented in it. Entries before that date can contribute to their historical cycle totals, but never change the snapshot-based current balance. Expected salary is never credited automatically. The most recent salary date entered in onboarding is metadata only; confirmed salary is a separate ledger entry.

Current balance includes confirmed entries from snapshot date through today. Expenses subtract, salary/income/refunds/positive adjustments add. Negative adjustments can be recorded as expenses with an explanatory note. Cycle income includes salary and extra income; cycle spending includes expenses. Refunds change balance separately. Changes to target/salary configuration leave historical transactions intact.

Reserved savings = max(monthly target, user-confirmed actual savings held inside the current balance). Opening cash funds this reserve too. Available = current balance - reserve; no clamping at zero. Daily amount divides by local calendar days through the day before next payday, including today; positive cents round down, negative cents away from zero. Confirmed savings is a dated user attestation, not inferred wealth or a second balance. Update it after drawing down savings. Clearing site/app storage can erase guest data. JSON backups are unencrypted user-owned financial files.

## Modules

lib/app: application shell, state and common form widgets.
lib/core: ledger/backup schema, financial service, Drift database and theme.
lib/features: onboarding, monster, transactions, import, shop and settings.
android, ios, web: native project/hosting configuration. tool/generate_icons.ps1 packages the supplied assets/videos/icon.png into all launcher icon sizes.

## Explicit limitations / before public stores

TNG import supports the supplied daily TNG WALLET TRANSACTION HISTORY table format, including rotated landscape/password-protected PDFs. Phone setup normalizes a Malaysian number and removes its leading 0 to unlock locally. The number is kept in platform protected storage, excluded from financial backups, editable/removable in Settings, and cleared on reset. No PDF is uploaded or retained. Individual rows and import metadata are stored; dashboards show summed spending. Amount and Wallet Balance are parsed as separate columns. Payment / DuitNow QR are suggested expenses; unknown types, transfers and top-ups require explicit review or exclusion. Manual TNG entries with matching day/amount are initially unselected for duplicate review. Persistent reference fingerprints prevent reimports after edits or deletion. Pre-snapshot imports are history only and do not debit the opening cash twice. Multi-day, image-only, malformed or unrecognized layouts fail explicitly with manual fallback. Import then asks about other payment methods, opening a dated manual form if needed. Additional statement formats need verified fixtures before support is claimed.

No real authentication is configured; Login/Register are disabled. iOS requires macOS/Xcode and is not validated on this Windows host. Android release currently uses the generated debug signing configuration for local release validation: configure a private upload keystore before submission. Confirm ownership of app.savingmonster.saving_monster before publishing; update Android applicationId/namespace and iOS bundle identifier if needed. Perform real Android/iOS device testing, browser backup/restore and offline/storage retention testing, accessibility review, signing/provisioning, privacy/store disclosures and screenshots before public release. Local database files are not encrypted; device security protects them.

Schema v1 creates the initial database; unsupported future migrations fail closed. Future releases must introduce and test explicit migrations before bumping schemaVersion. JSON backup version is separate from SQLite schema version.

For v0.0.2: additional verified TNG layouts, real-device notification acceptance tests, signed device releases, savings transfer accounts and stronger browser persistence acceptance checks.


## Validation on 2026-10-28 (Windows)

- flutter pub get: passed.
- dart run build_runner build: generated Drift database code.
- flutter analyze: passed with no issues.
- flutter test: all 5 focused checks passed, including 360×800 portrait rendering, local-date payday boundaries, integer ledger arithmetic, backup validation, SQLite schema creation/reopen/rollback and stale-write rejection.
- flutter build web --release: passed. The deployable offline bundle is prepared by tool/build_web.dart (local renderer + custom versioned cache worker).
- flutter build apk --release: passed; build/app/outputs/flutter-apk/app-release.apk (about 64.4 MiB, debug-signed local validation build).
- iOS build: not attempted; compatible macOS/Xcode environment unavailable.
- Non-fatal build notice: missing optional Cupertino icon font. The SDK deprecated offline-first option was inspected and found to emit an unregister-only worker, so the release uses its own cache worker instead. Application icons use Material icons and original local mascot artwork.
- Browser and physical-device end-to-end acceptance testing has not been completed. Successful compilation is not a public production-readiness claim.

- dart run tool/build_web.dart: passed; final Web release built with a generated offline cache worker. After final path/hosting refinements, dart run tool/prepare_offline.dart passed; node --check and a manifest check verified all 37 cached resource paths exist, including database WASM/worker, renderer resources and the local font. dart analyze tool passed.

## Nightly recording reminders

New guest setup offers a nightly reminder (default 21:00); Settings can enable/disable it or change the time. Android/iOS request notification permission only from the setup/settings action, use the device timezone, and schedule recurring local notifications. Android uses inexact alarms (no special exact-alarm permission) and includes boot rescheduling; battery controls can delay delivery. Tapping a notification opens daily TNG import. A visible in-app evening card remains until the user explicitly finishes that day's other-payment review. A TNG import alone never marks all financial coverage complete. Web has the in-app reminder while open; closed-browser background notifications are not implemented. iOS notification delivery still requires macOS/device validation.

## Daily TNG follow-up validation

The supplied encrypted daily statement was opened locally using the user-provided unlock rule. The parser verified 3 transactions totaling 3,289 cents; document identity, merchant/reference metadata and distinct reference fingerprints were checked. An incorrect password was rejected. The private statement and phone number were not copied into application assets or committed fixtures.

Focused tests cover Malaysian phone normalization, portrait/rotated table geometry, separating transaction amount from wallet balance, unknown transfer review, fingerprint persistence through deletion/restore, and the actual dated cash-entry form for a pre-snapshot statement. Historical manual entries require confirmation and leave the snapshot-based balance unchanged.

Reminder delivery on physical Android/iOS hardware and browser end-to-end encrypted-file import still require device acceptance testing. Native iOS compilation remains unavailable on this Windows host.

Final follow-up checks: flutter analyze reported no issues; all 9 focused tests passed. The Web release and offline worker build passed with all 40 asset paths verified, including the local PDFium WASM module. Android release configuration includes notification permission/boot receivers, desugaring and the retained monochrome notification icon. The app continues to use the local validation signing key; use proper release signing before distribution.

2026-10-29 final artifact refresh: flutter analyze passed with no issues; all 9 tests passed; dart run tool/build_web.dart passed (40 cached assets, including local PDFium); flutter build apk --release passed (83.9 MiB local validation APK). The refreshed APK includes the historical other-payment entry flow. Physical-device notification delivery and iOS compilation remain unvalidated.


## Editing languages

English is the default. Settings → Language and the onboarding language selector switch between English and 简体中文 immediately. The choice is stored as `language` (`en` / `zh_CN`) in the local ledger JSON and included in portable backups. Old backups without this optional field default to English; changing language leaves financial values unchanged. Existing scheduled reminders are rescheduled with translated text, without requesting permissions again.

Edit `assets/i18n/en.json` for English and `assets/i18n/zh_CN.json` for Simplified Chinese. Keys are grouped by screen/module (for example `settings.019` is the Save settings button). Keep matching keys in both files and preserve placeholders such as `{p0}` and `{value}`; they contain dates, amounts or counts at runtime. Use JSON `\n` for line breaks. Restart the app after editing assets. No code generation or translation service is needed. `flutter test test/localization_test.dart` checks matching keys/placeholders, copy and language switching with retained form input.

Canonical transaction/payment codes stay consistent in storage and are displayed through the JSON labels. Flutter's date/time dialogs follow the selected locale, and Noto Sans SC is bundled for offline Simplified Chinese rendering.

2026-10-29 language update validation: flutter analyze passed with no issues; all 12 tests passed, including switching English ↔ Simplified Chinese with retained form input, preference persistence, old-backup fallback and catalog key/placeholder parity. The Web offline release and Android release APK built successfully with both JSON catalogs and Noto Sans SC. Offline manifest verification checked all 42 resources. iOS compilation and physical-device notification delivery remain unvalidated on this Windows host.


## First hatch and supplied artwork

There are four main screens (Home, Shop, History, Settings), six onboarding steps, and inline expense/income/refund/TNG panels. The first onboarding step now has loading -> hatching -> Flame reveal states. `loading.mp4` loops silently with a localized outlined title and egg prompt; tapping the egg starts `intro.mp4`. Both supplied clips are 720x1280 H.264/AAC, approximately 3.042 seconds. The intro plays at its original 1.0x speed (approximately 3.042 seconds), and media completion triggers the monster reveal. Playback pauses in the background, both controllers are disposed after leaving, and unsupported/failed playback offers an explicit retry or video-free reveal. The completed hatch is stored separately from financial setup and is included in backups. Returning users do not replay it; resetting data clears it.

`assets/images/monster/baby_atlas.png` contains reference-based transparent idle/happy/sad poses. Flame displays individual frames from `baby_atlas.json`; measured crop bounds preserve the tail and uniform scaling preserves proportions. Existing levels, coins and equipped props persist. Stage aura/size accents distinguish levels while using the supplied Baby art; distinct grown-stage artwork has not been invented. Extraction mode and the final built-in imagegen prompt are recorded in `tool/artwork/README.md`.

`assets/videos/icon.png` is the supplied launcher source. Generated Android legacy/adaptive, iOS and Web icons use that artwork, with opaque iOS output and a safe adaptive foreground. Run `powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1` to regenerate them. New title, prompt, loading, error and reveal wording lives in both language JSON files under `hatch.*` and `monster.*`.

The offline Web worker serves cached MP4 byte ranges for browser playback. Hosts should serve MP4 as video/mp4 and support byte-range requests for the initial uncached visit. After adding platform plugins, regenerate stale build caches with `flutter clean` and `flutter pub get` before release validation. The normal JavaScript Web build is supported; the secure-storage/timezone package versions currently prevent an app-level `--wasm` build. This does not affect SQLite/PDF WebAssembly modules.

Historical validation before restoring original intro speed: muted loading playback, tap-to-hatch, intro playback rate 0.6084×, Flame sprite reveal and no replay after restart all passed with zero uncaught browser errors. The observed tap-to-reveal duration was about 5.56 seconds including startup/transition overhead; the complete media duration is normalized to five seconds. Review captures are in output/previews/first-hatch-loading.png and baby-monster-reveal.png. Full analysis and all 14 focused tests passed before release packaging.

2026-10-29 hatch release validation: the clean JavaScript Web release and Android release APK both passed. The APK packages both supplied videos, the transparent sprite atlas/manifest and both JSON catalogs. Real Chrome verification passed loading playback, the five-second intro, Flame reveal, persisted first-hatch state and an offline cached MP4 range response (206, 100 requested bytes) with zero uncaught browser errors. Android lint also passed after stopping a Gradle daemon that had locked its cache. The APK remains a debug-signed local validation release; iOS compilation and physical-device playback/notification delivery remain unvalidated.
Final post-packaging test rerun: all 14 tests passed, including hatch playback/lifecycle, sprite loading, first-hatch persistence and English/Simplified Chinese switching.
Final source analysis (flutter analyze --no-pub lib test tool): no issues found. The whole-workspace rerun stalled after packaging; targeting the three source directories completed successfully.
