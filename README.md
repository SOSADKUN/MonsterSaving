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


## Salary receipt and quiet homepage notices

Setup places a Received checkbox beside Monthly salary. Checking it reveals only a salary received date picker; no notes/payment-method fields are requested. The receipt is saved as a salary history entry already included in the entered current balance, with the received date retained, so setup never adds those funds a second time. A positive monthly salary is required before checking receipt can be saved.

The homepage no longer shows the new-pay-cycle salary card. An unconfirmed salary for the current pay cycle adds a red dot to Settings; Settings shows a compact pending-receipt action. It opens a short sheet with the saved salary amount and date picker, without notes. Confirming a later receipt records new salary income; dates before the opening snapshot remain history-only. Duplicate salary confirmation in the same pay cycle is rejected. Once receipt is recorded for the active cycle, the dot disappears; a later unconfirmed cycle can show it again.

The coverage notice is informational, at the bottom of the normal homepage dashboard. It has no tap handler or confirmation modal. Its X saves `coverageNoticeDismissedFor` for the current pay cycle and does not change `coverage` or claim records are complete. It stays hidden through restarts for that cycle, and can reappear next cycle if coverage is still unconfirmed. All new copy is in both language JSON catalogs. No tests, analysis or builds were run for this enhancement.

## TNG daily and date-range statements

The same TNG import screen accepts daily statements and multi-page date-range reports. Continuation pages reuse the first table's column geometry/orientation when headers are not repeated. Dates accept one/two-digit days and months (for example `1/10/2026`) and normalize to ISO dates for storage/fingerprints. Every row keeps its own transaction date; wallet balances remain separate from spending. The report period is read from the first-page date range, with earliest/latest transaction dates as a fallback. Rows outside the stated period or future-dated transactions are rejected rather than silently dropped. Existing 20 MB / 100-page limits remain; period metadata is bounded to 3,660 days for review bookkeeping.

The card shows a compact range above Total spending, and Review retains the vertical transaction table. Daily/monthly overlaps use the existing fingerprints, so already-recorded transactions are skipped. The other-payment question covers the full report period; choosing Yes opens manual entry with an editable date. On the homepage, explicitly choosing No finishes review for the covered calendar days up to today, never future days. Upload alone does not mark those days reviewed. Setup records remain included in the entered balance and do not deduct it again.

The supplied October date-range sample was inspected locally: 15 pages, 130 dated rows, headers only on page 1, unpadded dates on early days. The private PDF and supplied password were not added to project files or fixtures. No app tests, analysis or builds were run; native runtime import of the new format remains for user validation.

## Setup records and the starting balance

The opening balance is the user's current money, already reflecting all spending recorded during first-time setup. Every setup record (manual or TNG import, including today's records) is saved with `includedInOpeningBalance: true`. These entries still count toward their pay-cycle spending/income totals, but never debit/credit the balance again. For example, RM200 entered in setup plus an RM5.50 setup spending record leaves the balance at RM200 and reports RM5.50 spending. A new RM5.50 expense from the homepage + then changes the balance to RM194.50. Editing/restoring setup records preserves this flag; deleting one changes totals without refunding the starting balance.

Older entries without the flag retain their original behavior. Already-saved legacy setup records cannot be distinguished reliably from homepage entries and are not automatically reclassified. New setup completion marks all staged entries correctly. The internal opening date still protects historical entries added from the homepage from being deducted twice. Coin calculations use explicit integer fold types in ledger.dart. No tests, analysis or builds were run for these changes.

The supplied `assets/videos/background.png` is now bundled and used for the free meadow on the homepage and behind the monster after intro.mp4. It is precached during the hatch screen to prepare the reveal. Rebuild the app to include the new asset.

## Homepage monster activities and backgrounds

The homepage now uses a Flutter image-frame widget with a lifecycle-aware ticker, rather than its previous Flame game. The Baby is roughly a quarter smaller, leaving more room for backgrounds. Random activity periods include idle breathing, two-frame walking in either direction, strawberry snacking with a chewing motion, closed-eye sleep with breathing/Z effects, and playful hopping. Tapping wakes/reacts with a playful animation. The scene respects reduced-motion settings and pauses when the app is backgrounded; it does not award coins or change financial records for tapping or activities. Existing equipped accessories and level accents remain visible. The first-hatch reveal retains its separate existing Flame scene.

The new transparent activity art is in `assets/images/monster/baby_activities.png`, with measured crop bounds in its sibling JSON. Asset source, generation mode and the final prompt are in `tool/artwork/activity-sprites.md`. The original idle/happy/sad art remains in use.

The shop has a Backgrounds section backed by `assets/backgrounds/catalog.json`. Only the free gradient meadow is currently supplied. Future image assets, localized names and coin prices can be added there; see `assets/backgrounds/README.md`. Ownership and selected background are included in local saves, backup/restore and reset, independently of accessories. Missing images are not sold, and missing selected artwork falls back to the default meadow. This prepares future bundled backgrounds; an in-app image upload or real-money checkout is not included. No tests, analysis or builds were run for this enhancement, per the user's preference.

## Setup guide layout

The setup guide uses a fixed top-right language icon that opens a bottom-sheet selector. Login and sign-up are design-only forms for later Firebase integration: login accepts email/username and password; sign-up includes username, email, password and confirmation. Passwords have show/hide controls and local field validation. Submit displays an honest not-connected message; no credentials are saved/sent and no authenticated session is simulated. Continue as guest proceeds to setup.

TNG setup uses a masked Phone No field (show/hide, hidden by default), Remember this number and a black protected-local-storage note. The phone remains in the existing secure-storage service and is excluded from ledger backups. Financial setup keeps opening balance and monthly salary, uses a calendar picker for payday, and removes the visible opening-snapshot/recent-salary controls. The internal opening date defaults to the day setup started; the selected payday's day-of-month is the monthly schedule, and no previous salary receipt is inferred or credited.

The savings-goal content is retained. Complete your records shows spending date, amount, payment method, notes and Add in that order. Added/manual/imported entries appear in a phone-width table with Date, Details (method/notes), Amount and remove controls. The header stays above a vertically scrollable body capped at 340 logical pixels; there is no horizontal scrolling. The footer says Skip for now with no records, and Continue after records are added. Date fields open a short bottom-sheet calendar (160 ms entry, 120 ms dismissal), highlight immediately, block duplicate opens and select/close on a day tap; reduced-motion preferences are respected.

TNG import shows the saved Phone No as a label with an edit icon, then Select TNG PDF. After selection, the main card shows Total spending and a Review toggle, without record-count paragraphs, category explanations or an Enter manually instead button. Review opens a phone-width, vertically scrolling table with descriptions/dates, amounts, selection checkboxes and category controls. Existing/possible duplicates remain identifiable within the table. The displayed total is statement spending; Add records only imports selected new transactions. During setup, Add records stages them directly without a second explanatory confirmation dialog; homepage imports retain their balance-impact confirmation. A corrected number is saved to protected storage after it successfully opens a supported statement. During setup, the other-payment review card sits below the records and above Continue, and resets for the next upload. All new copy is in the English/Simplified Chinese JSON catalogs. No tests, analysis or builds were run for this enhancement, per the user's preference.

## Startup splash and icons

Each cold launch shows the centered `assets/videos/icon.png` on a pale green background with a slogan, while the saved language and app data load. It stays visible for at least 900 ms. The same splash remains visible during the app's ledger load and first-hatch video preparation, then switches straight to the initialized, started loading.mp4 loop (or the existing user's app); there is no intermediate startup spinner. Video errors still expose retry/skip controls. Edit `splash.slogan` in the English/Simplified Chinese JSON catalogs to change the sentence.

The launcher icon now uses `assets/videos/iconbg.png`. `tool/generate_icons.ps1` regenerates Android legacy/adaptive icons, iOS icons and Web icons from that file; separate native launch images come from `icon.png`. Android launch resources (including Android 12+) and the iOS launch storyboard use the matching splash artwork/background before Flutter shows the localized slogan. Rebuild and reinstall to apply native splash/icon changes. No tests or builds were run for this update, as requested.

## Money entry

All money fields use fixed two-decimal digit entry: typing `9`, `9`, `0` displays `0.09`, `0.99`, `9.90`. Backspace shifts the remaining digits back toward cents; clearing the field displays `0.00`. Select the full amount to replace an existing value. This applies to spending, income, balances, salary and savings targets through the shared MoneyField. Phone numbers and payday numbers keep their existing input behavior.

The shared formatter is in `lib/core/input/cents_input_formatter.dart`. It formats with strings, preserves integer-cent ledger storage and retains the existing amount limit. Automated tests and builds were not run for this change, as requested; validation is left to the user.

## Editing languages

English is the default. Settings → Language and the onboarding language selector switch between English and 简体中文 immediately. The choice is stored as `language` (`en` / `zh_CN`) in the local ledger JSON and included in portable backups. Old backups without this optional field default to English; changing language leaves financial values unchanged. Existing scheduled reminders are rescheduled with translated text, without requesting permissions again.

Edit `assets/i18n/en.json` for English and `assets/i18n/zh_CN.json` for Simplified Chinese. Keys are grouped by screen/module (for example `settings.019` is the Save settings button). Keep matching keys in both files and preserve placeholders such as `{p0}` and `{value}`; they contain dates, amounts or counts at runtime. Use JSON `\n` for line breaks. Restart the app after editing assets. No code generation or translation service is needed. `flutter test test/localization_test.dart` checks matching keys/placeholders, copy and language switching with retained form input.

Canonical transaction/payment codes stay consistent in storage and are displayed through the JSON labels. Flutter's date/time dialogs follow the selected locale, and Noto Sans SC is bundled for offline Simplified Chinese rendering.

2026-10-29 language update validation: flutter analyze passed with no issues; all 12 tests passed, including switching English ↔ Simplified Chinese with retained form input, preference persistence, old-backup fallback and catalog key/placeholder parity. The Web offline release and Android release APK built successfully with both JSON catalogs and Noto Sans SC. Offline manifest verification checked all 42 resources. iOS compilation and physical-device notification delivery remain unvalidated on this Windows host.


## First hatch and supplied artwork

Salary receipt clarification (2026-10-30): confirming a salary in Settings now asks whether it is already reflected in the current balance. The dialog displays the actual balance and salary, with explicit record-only versus add-to-balance choices and resulting balances. Cancel saves nothing. A salary already received before setup can therefore be recorded without crediting it again, even if it has since been spent. Receipts dated before the opening balance remain automatically record-only. Both English and Simplified Chinese copy are in the language JSON catalogs. No tests or builds were run for this enhancement, following the user's preference.

Companion update (2026-10-30): after the original-speed intro, the first hatch randomly awards Mint Monster or Sprout Hamster with equal probability. The awarded companion is free and saved before continuing. Existing saves keep Mint Monster. Shop > Your companions lets users unlock the other for 100 earned coins and switch between owned companions; the selection replaces the homepage character without changing financial records or progress. Prices live in `Ledger.companionPrices`; labels live in both language JSON files. The hamster uses transparent image frames for idle, cheering, sad, walking, eating, sleeping and blinking, with Flutter activities on the homepage. Backup/restore and reset include companion ownership, purchase costs and active choice. Artwork details and the final generation prompt: `tool/artwork/hamster-sprites.md`. No tests or builds were run for this change, per user preference; rebuild to include the new assets.

There are four main screens (Home, Shop, History, Settings), six onboarding steps, and inline expense/income/refund/TNG panels. The first onboarding step now has loading -> hatching -> Flame reveal states. `loading.mp4` loops silently with a localized outlined title and egg prompt; tapping the egg starts `intro.mp4`. Both supplied clips are 720x1280 H.264/AAC, approximately 3.042 seconds. The intro plays at its original 1.0x speed (approximately 3.042 seconds), and media completion triggers the monster reveal. Playback pauses in the background, both controllers are disposed after leaving, and unsupported/failed playback offers an explicit retry or video-free reveal. The completed hatch is stored separately from financial setup and is included in backups. Returning users do not replay it; resetting data clears it.

`assets/images/monster/baby_atlas.png` contains reference-based transparent idle/happy/sad poses. Flame displays individual frames from `baby_atlas.json`; measured crop bounds preserve the tail and uniform scaling preserves proportions. Existing levels, coins and equipped props persist. Stage aura/size accents distinguish levels while using the supplied Baby art; distinct grown-stage artwork has not been invented. Extraction mode and the final built-in imagegen prompt are recorded in `tool/artwork/README.md`.

`assets/videos/icon.png` is the supplied launcher source. Generated Android legacy/adaptive, iOS and Web icons use that artwork, with opaque iOS output and a safe adaptive foreground. Run `powershell -ExecutionPolicy Bypass -File tool/generate_icons.ps1` to regenerate them. New title, prompt, loading, error and reveal wording lives in both language JSON files under `hatch.*` and `monster.*`.

The offline Web worker serves cached MP4 byte ranges for browser playback. Hosts should serve MP4 as video/mp4 and support byte-range requests for the initial uncached visit. After adding platform plugins, regenerate stale build caches with `flutter clean` and `flutter pub get` before release validation. The normal JavaScript Web build is supported; the secure-storage/timezone package versions currently prevent an app-level `--wasm` build. This does not affect SQLite/PDF WebAssembly modules.

Historical validation before restoring original intro speed: muted loading playback, tap-to-hatch, intro playback rate 0.6084×, Flame sprite reveal and no replay after restart all passed with zero uncaught browser errors. The observed tap-to-reveal duration was about 5.56 seconds including startup/transition overhead; the complete media duration is normalized to five seconds. Review captures are in output/previews/first-hatch-loading.png and baby-monster-reveal.png. Full analysis and all 14 focused tests passed before release packaging.

2026-10-29 hatch release validation: the clean JavaScript Web release and Android release APK both passed. The APK packages both supplied videos, the transparent sprite atlas/manifest and both JSON catalogs. Real Chrome verification passed loading playback, the five-second intro, Flame reveal, persisted first-hatch state and an offline cached MP4 range response (206, 100 requested bytes) with zero uncaught browser errors. Android lint also passed after stopping a Gradle daemon that had locked its cache. The APK remains a debug-signed local validation release; iOS compilation and physical-device playback/notification delivery remain unvalidated.
Final post-packaging test rerun: all 14 tests passed, including hatch playback/lifecycle, sprite loading, first-hatch persistence and English/Simplified Chinese switching.
Final source analysis (flutter analyze --no-pub lib test tool): no issues found. The whole-workspace rerun stalled after packaging; targeting the three source directories completed successfully.

Android decoder fix (2026-10-29): a connected Android 10 phone reported OMX.hisi.video.decoder.avc buffer-allocation/start failures while both onboarding clips were initialized concurrently (the format itself was reported supported). Loading now owns the only video player; tapping the egg fully disposes it before creating the original-speed intro player. Retry also awaits old player disposal. The focused hatch regression fake rejects concurrent video players, and both hatch tests pass.
Single-decoder release validation: focused hatch tests passed (2/2), changed-source analysis reported no issues, and the refreshed Android release APK built successfully. The connected phone disconnected before installation, so playback of this fix on that device remains unverified. No device data was cleared.
The phone subsequently reconnected and adb install -r -t succeeded, preserving data; app launch was requested. The user chose to handle subsequent installation/playback checks themselves, so real-device playback remains unconfirmed.

Android software-decoder update (2026-10-29): the prior single-player change was insufficient. The Huawei Android 10 device still failed to allocate buffers for OMX.hisi.video.decoder.avc with loading.mp4 alone. A local BSD-licensed video_player_android 2.9.5 override now prefers MediaCodecSelector.PREFER_SOFTWARE and enables decoder-initialization fallback in both texture/platform-view factories. Upstream Dart APIs, original videos, 1.0x playback, looping and completion behavior are retained. See packages/video_player_android/SAVING_MONSTER_PATCH.md for maintenance notes.

The updated debug APK built and installed over existing app data successfully. Device logs confirm c2.android.avc.decoder was created without the previous decoder-initialization error. The user chose to handle visual playback checks themselves, so complete visual confirmation remains pending. The current test APK is build/app/outputs/flutter-apk/app-debug.apk; the older app-release.apk does not contain this software-first patch.

Android MainActivity sets FLAG_KEEP_SCREEN_ON on resume and clears it on pause. This keeps the screen awake across app screens while Saving Monster is foregrounded, and allows normal screen sleep when leaving the app. No wake-lock permission or background service is used. This change currently applies to Android.

Primary API references: https://developer.android.com/reference/androidx/media3/exoplayer/mediacodec/MediaCodecSelector and https://developer.android.com/develop/background-work/background-tasks/awake/screen-on .
Regression validation after the software-decoder override: all 14 Flutter tests passed.

Preloaded hatch transition and corner badge (2026-10-29): loading.mp4 initializes first and starts looping while intro.mp4 prepares paused in the background using Android's software-first decoder patch. Both video widgets are mounted ahead of the tap. A normal egg tap pauses the loop and plays the prepared intro at 1.0x; it does not dispose/create/initialize a video controller or show a transition spinner. If tapped unusually early, the loop remains visible until the pending preparation completes, then switches automatically. Only one clip plays at a time, and both players are disposed when leaving the screen.

A fully opaque, cream-and-green Saving Monster badge covers the bottom-right watermark region in both video views. The badge is anchored to the viewport so BoxFit.cover cannot clip its title. It reuses hatch.titleTop/hatch.titleBottom from the English/Simplified Chinese JSON catalogs. The original MP4 files are unchanged. Regression tests cover preloading before tapping, immediate playback without creating another player, early taps retaining the loop with no spinner, pause/resume, completion, disposal and the badge on both clips.
Preload/corner-cover validation: all 15 tests passed; changed-source analysis reported no issues; Android debug APK and JavaScript Web release built. In isolated Chrome, both clips were prepared before tapping, no extra player was created on tap, intro playback began approximately 169 ms after the touch request, and playback rate was 1.0. Tap-to-completion was approximately 3.59 seconds including browser/check overhead. First-hatch persistence, offline MP4 byte ranges (206, 100 requested bytes) and zero uncaught browser errors were verified. Visual inspection confirmed the bottom-right watermark is hidden behind the localized badge; updated loading/intro previews are in output/previews. The current Android artifact is build/app/outputs/flutter-apk/app-debug.apk; real-phone timing of this preload change remains for user validation.
