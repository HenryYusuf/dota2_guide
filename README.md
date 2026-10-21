# Aegis Codex — Dota 2 Reference

An unofficial, offline-first Dota 2 reference companion app for Android. Browse heroes, items, abilities, and patch notes without a network connection.

## Development

### Snapshot Pipeline

Aegis Codex bundles official datafeeds from Valve (`dota2.com/datafeed`) as offline assets (ADR-0001).

- **Bundle snapshot**:
  ```bash
  dart run tool/snapshot.dart
  ```
- **Validate schema (release gate)**:
  Re-pulls the live feeds and diffs schema shape against committed assets to catch Valve-side drift:
  ```bash
  dart run tool/snapshot.dart --validate
  ```

### Testing & CI

- Run static analysis:
  ```bash
  flutter analyze
  ```
- Run the full test suite (parsing, repository, widget, and cross-screen smoke tests):
  ```bash
  flutter test
  ```

### Release Checklist

See [docs/release-checklist.md](docs/release-checklist.md) for the mandatory release gate procedure before publishing any new release.
