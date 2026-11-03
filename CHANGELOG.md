# Changelog

## [Unreleased]

### Added
- **Linux sideload helper**: added `scripts/linux-sideload.sh` that signs the unsigned CI .ipa with a free Apple ID (node-applesign) and installs it over USB (ideviceinstaller), so the app runs like a normal iPhone app without a macOS/Windows machine.
- **iOS build pipeline**: `.github/workflows/ios-build.yml` builds an unsigned iOS app on `macos-latest` on every push to `main` (or manual dispatch) and uploads it as the `ios-build-app` artifact, ready for Sideloadly — no Apple Developer Account required.
- **iOS platform scaffolding**: committed `frontend/ios/` (bundle id `com.devlex.itGlossary`, display name DevLex) with full-bleed DevLex app icons generated from the shared branding logo, so the app no longer ships with Flutter's default icon on iPhone.
- **Tier-2 always visible**: The "TẦNG 2 — BỐI CẢNH & TRỰC QUAN" card now renders for every term, even when `detailedExplanation` or `metaphorAnalogy` is missing. Users no longer encounter terms with a gap between Tier 1 and Tier 3.
- **Structured explanation sections**: `detailedExplanation` text containing `###` headings is split into titled sub-sections with colored icons, making Tier 2 visually distinct from the Tier 1 definition instead of a duplicated wall of text.
- **Enlarged, colored flow-diagram arrows**: Arrows in the context flow board are now 18 px and use the Tier-2 accent color so the drawn relationships are immediately obvious.
- **Richer context diagram**: The flow board now displays up to 4 related/prerequisite terms (was 2), giving users more visual context per term.
- **Widget test `term_detail_tier2_test`**: Two new tests guarantee that the Tier-2 card and its flow diagram always render for terms with and without `###` sections.

### Changed
- **iOS artifact is now a real .ipa**: the pipeline emits `DevLex-unsigned.ipa` (`Payload/Runner.app` at the root) instead of a .zip, because Sideloadly rejects a zip or a bare .app folder and needs the .ipa extension.
- **Device-build guard**: CI now asserts `DTPlatformName == iphoneos` and an `arm64` `Runner` binary, so a simulator build can never ship by mistake.
- `delta_sync_flow_test`: Assertions for trust and attribution cards now use `skipOffstage: false`, because the always-on Tier-2 card makes the detail screen taller and pushes lower cards below the test viewport fold.

### Fixed
- **Seed data cleanup** (from prior commit, carried into this release): Pruned junk entries (math symbols, 1–2 char variable names, NIST/IETF formula fragments) from `terms.json` (6 555 → 1 253 clean terms). Added ~150 modern DevLex-authored terms (React, K8s, AWS, Kafka, LLM, RAG, OWASP Top 10, …) with real prerequisites so roadmap arrows have meaning.
- **Roadmap centering**: `_fitToView`/`_zoomTo` now use the actual map-viewport size from `LayoutBuilder` instead of a possibly-null `context.size`, fixing off-center roadmap diagrams.
