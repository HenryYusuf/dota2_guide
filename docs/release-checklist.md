# Aegis Codex — Release Checklist

This checklist is the required release gate for Aegis Codex. Every step must be executed in order before tagging and publishing a new release.

---

## 1. Schema Validation (Mandatory Release Gate)

Before snapshotting or publishing, verify that Valve has not introduced schema drift into the live datafeeds (ADR-0001, User Story 42).

- [ ] **Run the snapshot validator against official feeds**:
  ```bash
  dart run tool/snapshot.dart --validate
  ```
  *(Optional: `--heroes-only`, `--items-only`, or `--patches-only` can be passed to isolate checks).*

- [ ] **Verify zero drift**:
  - The command must exit with code 0 and output `SCHEMA VALIDATION PASSED`.
  - **Do NOT proceed** if drift is reported. If Valve modified field types, renamed keys, or altered feed envelope structures:
    1. Read the `[DRIFT]` report emitted by the tool.
    2. Update converters (`hero_feed_to_*.dart`, `item_feed_to_*.dart`, `patch_feed_to_*.dart`) and models (`HeroDetail`, `ItemDetail`, etc.) as needed.
    3. Update the pinned parsing tests under `test/features/*/`.
    4. Re-run `dart run tool/snapshot.dart --validate` until validation passes cleanly.

---

## 2. Snapshot Bundling (When Updating Game Data)

Only run snapshot regeneration **after** schema validation has passed.

- [ ] **Regenerate bundled snapshot assets**:
  ```bash
  dart run tool/snapshot.dart
  ```
  This emits `heroes.english.json`, all `hero_<id>.english.json` detail files, `items.english.json`, all listable `item_<id>.english.json` files, `patches.english.json`, and the latest `patch_<patchNumber>.english.json` into `assets/data/`.

- [ ] **Inspect git status & diff**:
  ```bash
  git status
  git diff --stat assets/data/
  ```

---

## 3. Automated Quality Gates

All automated checks must pass without warnings or errors.

- [ ] **Check code formatting**:
  ```bash
  dart format --output=none --set-exit-if-changed .
  ```

- [ ] **Run static analysis**:
  ```bash
  flutter analyze
  ```
  Must report `No issues found!`.

- [ ] **Run test suite**:
  ```bash
  flutter test
  ```
  Must execute and pass all test suites:
  - **Parsing tests**: verify strict reader contracts against committed fixtures (`assets/data/*.json`).
  - **Repository tests**: verify offline-first loading, fallback, and 24 h TTL refresh policies.
  - **Widget tests**: verify UI rendering across components and screens.
  - **Cross-screen smoke test** (`test/cross_screen_smoke_test.dart`): verifies end-to-end navigation across Home, Heroes, Items, Patches, and About.

- [ ] **Verify CI status**:
  Ensure GitHub Actions CI workflow (`.github/workflows/ci.yml`) is green on the release branch.

---

## 4. Legal, Branding & Attribution Check

Confirm full compliance with legal decisions (ADR-0001, GLOSSARY):

- [ ] **No proprietary Valve assets bundled**:
  - No KV files (`npc_heroes.txt`, `items.txt`, etc.).
  - No Valve icons, ability images, or demo videos bundled in the APK/AAB (all stream via Steam CDN at runtime).
  - Launcher icon uses original artwork (no Valve logo, hero faces, or Dota 2 trademark).
- [ ] **About screen verification**:
  - Disclaimer is present and visible: `"Unofficial — not affiliated with Valve Corporation. Dota 2 and related marks are trademarks of Valve Corporation."`.
  - Attributions listed: Valve official datafeeds, Steam CDN, Steam news feed.

---

## 5. Build & Distribution

- [ ] **Update version in `pubspec.yaml`**:
  Increment `version: <major>.<minor>.<patch>+<buildNumber>`.

- [ ] **Build Android Release Artifact**:
  ```bash
  flutter build appbundle --release
  ```
  *(or `flutter build apk --release` for direct distribution).*

- [ ] **Smoke test release build**:
  Install the release artifact on a physical device or emulator.
  - Test initial launch in airplane mode (offline): confirm Home, Heroes, Items, and Patches tabs load bundled snapshot data cleanly with zero crashes.
  - Connect to network: confirm image streaming from CDN and news load.
