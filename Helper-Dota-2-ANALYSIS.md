# Helper Dota 2 (`com.alexter.dota2helper`) — Reverse Engineering Report

> **Target artifact:** `Helper Dota 2.apk`
> **SHA-256:** `4fbd847915ac6e0022386b167f61299ca23cf6bc643710ed5711825d6db31015`
> **Analysis date:** 2026-10-20
> **Method:** REA (archive identity/inventory) + jadx-headless (DEX decompilation) + manual Hermes bytecode string-table recovery
> **Purpose:** Technical teardown to enable an independent re-implementation

---

## 0. Executive summary

Helper Dota 2 is an **Expo / React Native** (SDK 53) reference app for Dota 2, built with Kotlin 2.0.21 / Gradle 8.13 / Hermes, released through Google Play, wrapped in **PairIP** DRM, and shipped with **EAS Update** OTA capability.

The app is **offline-first**: ~90% of the 48.8 MB JS bundle is inlined, per-language Dota 2 game data (converted from Valve's KV files), while icons and ability-demo videos are streamed live from Valve's CDN. Live data comes from the developer's own backend (`https://api.dota2helper.pro`) and from OpenDota. Monetization is a web-checkout **Premium subscription** (Play Billing is not bundled) plus a config-gated **ads** surface (disabled in this build).

Five tabs: **Home, Heroes, Items, Picker, Profile**, plus a **Library** sub-tree (Heroes, Items, Creeps, Guides + quiz, interactive Map, Patch Notes, Dota 1 content) and Premium/Profile/Stats screens.

---

## 1. Identity & fingerprint

| Field | Value | Source |
|---|---|---|
| Package | `com.alexter.dota2helper` | `AndroidManifest.xml` |
| Version | `1.6.4` (versionCode `27`) | `BuildConfig`, `app.config` |
| minSdk / targetSdk | `24` / `36` | manifest |
| compileSdk / buildTools | `36` / `36.0.0` | `expo-build-properties` plugin |
| JVM target | Java 17 | `kotlin-tooling-metadata.json` |
| Gradle | `8.13` | `kotlin-tooling-metadata.json` |
| Kotlin | `2.0.21` | `kotlin-tooling-metadata.json` |
| DEX files | 6 (`classes.dex` … `classes6.dex`) | archive root |
| Decompiled classes | 20,568 | jadx-headless |
| Resources | 2,437 | jadx-headless |
| JS bundle | 48,848,840 B Hermes bytecode | `assets/index.android.bundle` |
| Bundle contents | 41,746 strings / 25,646 functions | Hermes header |
| Expo assets | 1,302 entries | `assets/app.manifest` |
| Build/OTA commit | 2026-10-12 (`1791819630671`) | `app.manifest` commitTime |
| Debug | `DEBUG = false` | `BuildConfig` |
| Hermes | enabled | `BuildConfig.IS_HERMES_ENABLED = true` |
| New Architecture | **disabled** | `BuildConfig.IS_NEW_ARCHITECTURE_ENABLED = false` |

### Permissions

```
android.permission.INTERNET
android.permission.READ_EXTERNAL_STORAGE
android.permission.WRITE_EXTERNAL_STORAGE
android.permission.VIBRATE
android.permission.WAKE_LOCK
android.permission.ACCESS_NETWORK_STATE
android.permission.ACCESS_WIFI_STATE
android.permission.ACCESS_ADSERVICES_ATTRIBUTION
android.permission.ACCESS_ADSERVICES_AD_ID
com.google.android.providers.gsf.permission.READ_GSERVICES
com.google.android.gms.permission.AD_ID
com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE
com.android.vending.CHECK_LICENSE
com.alexter.dota2helper.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION
```

---

## 2. How the app was built

### 2.1 Stack

| Layer | Technology | Evidence |
|---|---|---|
| UI | **React Native + Expo SDK 53** | `app.config` → `"sdkVersion":"53.0.0"`; 1,064 `expo.modules` classes; `expo-router` assets present |
| Routing | **expo-router** (file-based) | 31 route paths recovered (§5.1) |
| Language | **TypeScript + Flow** | Kotlin `@Metadata` stubs; `main.js.flow-enums-runtime`, `featureflags/index.js.flow` |
| Engine | **Hermes** (bytecode v96) | `IS_HERMES_ENABLED = true`; bundle magic `c6 1f bc 03`, version `96` |
| Architecture | **Old architecture** (New Arch off) | `IS_NEW_ARCHITECTURE_ENABLED = false` |
| Native host | **Kotlin 2.0.21**, JVM target 17 | `kotlin-tooling-metadata.json` |
| Build system | **Gradle 8.13**, compileSdk 36, buildTools 36.0.0 | `expo-build-properties` in `app.config` |
| Bundler | **Metro** (Expo) | `getJSMainModuleName() = ".expo/.virtual-metro-entry"` |
| OTA | **EAS Update** (`expo-updates`), `WIFI_ONLY` | `updates.url = https://u.expo.dev/e36186af-6040-4910-adad-3efc2fb0808f` |
| Lists | **@shopify/flash-list** | `com.shopify.reactnative.flash_list` (10 classes) |
| Animation | **Reanimated** (+ Gesture Handler) | `com.swmansion` (202 classes) |

### 2.2 Project configuration (recovered from `assets/app.config`)

```jsonc
{
  "name": "Helper Dota 2",
  "slug": "Dota2Helper",
  "version": "1.6.4",
  "sdkVersion": "53.0.0",
  "runtimeVersion": "1.6.4",
  "platforms": ["ios", "android", "web"],
  "scheme": "dota2helper",
  "userInterfaceStyle": "dark",
  "icon": "./assets/adaptive-icon3-big.png",
  "splash": { "image": "./assets/splash.png", "resizeMode": "contain", "backgroundColor": "#000000" },
  "assetBundlePatterns": ["**/*"],
  "ios": { "supportsTablet": true },
  "android": {
    "package": "com.alexter.dota2helper",
    "versionCode": 27,
    "edgeToEdgeEnabled": true,
    "usesCleartextTraffic": false,
    "backgroundColor": "#000000",
    "adaptiveIcon": { "foregroundImage": "./assets/adaptive-icon3-big.png", "backgroundColor": "#000000" },
    "googleServicesFile": "./google-services-googleplay.json"
  },
  "web": { "bundler": "metro", "output": "single", "favicon": "./assets/favicon.png" },
  "updates": {
    "url": "https://u.expo.dev/e36186af-6040-4910-adad-3efc2fb0808f",
    "fallbackToCacheTimeout": 0,
    "checkAutomatically": "WIFI_ONLY"
  },
  "extra": {
    "eas": { "projectId": "e36186af-6040-4910-adad-3efc2fb0808f" },
    "appVersion": "1.6.4",
    "buildId": "98133d65",
    "storeChannel": "googleplay",
    "ads": {
      "enabled": false,
      "provider": "none",
      "yandex": { "bannerAdUnitId": "" },
      "inline": { "enabled": false, "preview": false, "placements": "home,library" },
      "offer": { "id": "demo-gaming-gear", "source": "affiliate",
                 "destinationUrl": "https://market.yandex.ru/", "active": true }
    },
    "premium": { "enabled": false },
    "dota1":   { "enabled": true },
    "previewRelease": false
  },
  "plugins": [
    "@react-native-firebase/app",
    "expo-updates",
    "expo-localization",
    ["expo-build-properties", { "android": {
      "buildToolsVersion": "36.0.0", "compileSdkVersion": 36, "targetSdkVersion": 36 } }]
  ]
}
```

`extra` is read at runtime through `expo-constants` — it is a **remote feature-flag surface** (ads / premium / dota1 toggles) that the shipped Play build ships with ads and premium disabled.

### 2.3 Native modules present in the APK

| Package | Classes | Role |
|---|---|---|
| `com.facebook.react` | 860 | React Native core |
| `expo.modules` | 1,064 | Expo native modules |
| `io.appmetrica` | **2,086** | Yandex AppMetrica analytics SDK |
| `com.google.firebase.auth` | 189 | Firebase Auth |
| `com.swmansion` | 202 | Reanimated / Gesture Handler |
| `com.reactnativecommunity.webview` | 28 | Embedded WebView |
| `com.shopify.reactnative.flash_list` | 10 | FlashList |
| `com.pairip` | 11 | **PairIP DRM / license gate** |
| `com.reactnativecommunity.asyncstorage` | present | AsyncStorage |
| `com.google.android.gms.ads.identifier` | 4 | Advertising ID only (no AdMob UI) |

**Expo sub-modules present:** `updates` (136), `video` (111), `filesystem` (55), `webbrowser` (13), `font` (8), `localization` (7), `keepawake` (7), `splashscreen` (6), `application` (6), `asset` (6), `device` (3).

**Absent (notable):** `expo-notifications`, `expo-haptics`, `expo-image`, `expo-sqlite`, `expo-securestore`, `expo-filepicker`, `expo-intent-launcher`, Play Billing (`com.android.billingclient` = 0), Yandex Ads (`ru.ydn` = 0), RevenueCat, `ru.rustore.*` (0).

### 2.4 Library versions embedded in the APK root

`*.properties` files shipped at the archive root reveal the dependency set:

| Component | Version |
|---|---|
| `firebase-analytics` | 22.4.0 |
| `firebase-auth` | 23.2.0 |
| `firebase-auth-interop` | 20.0.0 |
| `firebase-annotations` | 16.2.0 |
| `firebase-database-collection` | 18.0.1 |
| `firebase-measurement` / `-connector` / `-api` / `-base` / `-impl` / `-sdk` | 22.4.0 / 19.0.0 / 22.4.0 / 22.4.0 / 22.4.0 / 22.4.0 |
| `googleid` | 1.1.0 |
| `integrity` | 1.3.0 |
| `recaptcha` | 18.6.1 |
| `play-services-base` / `-basement` | 18.5.0 |
| `play-services-auth` | 21.4.0 |
| `play-services-auth-base` | 18.0.10 |
| `play-services-ads-identifier` | 18.1.0 |
| `play-services-appset` | 16.1.0 |
| `play-services-fido` | 20.1.0 |
| `play-services-stats` | 17.0.2 |
| `play-services-tasks` | 18.2.0 |
| `core-common` | 2.0.3 |

### 2.5 App-written native code (only 2 classes)

#### `MainActivity.kt`

```kotlin
public final class MainActivity extends ReactActivity {
    @Override protected void onCreate(Bundle savedInstanceState) {
        SplashScreenManager.INSTANCE.registerOnActivity(this);
        super.onCreate(null);                  // no saved state; RN re-creates
        proceedRuStorePayIntent(getIntent());
    }

    @Override public void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        proceedRuStorePayIntent(intent);
    }

    // Reflective RuStore payment callback — absent in the Google Play build
    private final void proceedRuStorePayIntent(Intent intent) {
        if (intent == null) return;
        try {
            Object obj = Class.forName("ru.rustore.react.pay.RuStoreReactPayModule")
                             .getField("Companion").get(null);
            obj.getClass().getMethod("processIntent", Intent.class).invoke(obj, intent);
        } catch (Throwable unused) { }
    }

    @Override protected String getMainComponentName() { return "main"; }

    @Override protected ReactActivityDelegate createReactActivityDelegate() {
        return new ReactActivityDelegateWrapper(this, false,
            new DefaultReactActivityDelegate(this, getMainComponentName(),
                DefaultNewArchitectureEntryPoint.getFabricEnabled()) { });
    }

    @Override public void invokeDefaultOnBackPressed() {
        if (Build.VERSION.SDK_INT <= 30) {      // Android 11: minimize instead of exit
            if (moveTaskToBack(false)) return;
            super.invokeDefaultOnBackPressed();
            return;
        }
        super.invokeDefaultOnBackPressed();
    }
}
```

#### `MainApplication.kt`

```kotlin
public class MainApplication extends Application implements ReactApplication {
    private final ReactNativeHost reactNativeHost = new ReactNativeHostWrapper(this,
        new DefaultReactNativeHost(this) {
            getUseDeveloperSupport() -> false
            isHermesEnabled()       -> true
            getIsNewArchEnabled()   -> isNewArchEnabled  // false
            getJSMainModuleName()   -> ".expo/.virtual-metro-entry"
            getPackages() -> new PackageList(this).getPackages()
                             + AppIconPackage
                             + reflective "ru.rustore.react.pay.RuStoreReactPayPackage"
        });

    @Override public void onCreate() throws IOException {
        super.onCreate();
        SoLoader.init(this, OpenSourceMergedSoMapping.INSTANCE);
        ApplicationLifecycleDispatcher.onApplicationCreate(this);
    }
}
```

#### `AppIconModule.kt` — dynamic launcher icon

```kotlin
public final class AppIconModule extends ReactContextBaseJavaModule {
    private static final String CLASSIC_ICON_KEY = "classic";
    private static final String DEFAULT_ICON_KEY = "gold";
    private static final String GOLD_ICON_KEY    = "gold";

    getName() -> "AppIconModule"
    @ReactMethod getCurrentAppIcon(Promise)
    @ReactMethod setAppIcon(String iconKey, Promise)
    resolveCurrentIconKey()  // resolves ComponentName against PackageManager
    isManifestEnabled(String componentName)
    normalizeIconKey(String)
    getIconComponents() -> LinkedHashMap  // icon key -> component
}
```

This is why the LAUNCHER activity is `com.alexter.dota2helper.GoldIconAlias` — an `activity-alias` on `MainActivity` so the icon can be swapped at runtime.

### 2.6 DRM wrapper — PairIP

```java
package com.pairip.application;
public class Application extends com.alexter.dota2helper.MainApplication {
    @Override protected void attachBaseContext(Context context) {
        LicenseClient.checkLicense(context);   // runs BEFORE any app code
        super.attachBaseContext(context);
    }
}
```

- Manifest `android:name="com.pairip.application.Application"`
- PairIP classes: `com.pairip.application.Application`, `com.pairip.licensecheck.{LicenseActivity, LicenseClient, ILicenseV2ResultListener, LicenseCheckException, …}`
- **Every process start is gated** by a license check that typically fails closed.

### 2.7 Release hardening

- `android:usesCleartextTraffic="false"` — no plaintext HTTP egress
- `android:extractNativeLibs="false"` (uncompressed native libs) + `android:largeHeap="true"`
- `android:enableOnBackInvokedCallback="false"`
- `android:allowBackup="true"` with `res/xml/*_provider_paths.xml` (file sharing)
- `android:appComponentFactory="androidx.core.app.CoreComponentFactory"`
- Baseline profile: `assets/dexopt/baseline.prof` (+ `.profm`)
- `stamp-cert-sha256` at archive root (signing metadata)

### 2.8 Manifest component summary

**Activities:** `MainActivity`, `expo.modules.video.FullscreenPlayerActivity` (PiP, `supportsPictureInPicture="true"`), `com.google.firebase.auth.internal.GenericIdpActivity`, `com.google.firebase.auth.internal.RecaptchaActivity`, `androidx.credentials.playservices.HiddenActivity`, `com.google.android.gms.auth.api.signin.internal.SignInHubActivity`, `com.google.android.gms.common.api.GoogleApiActivity`, `com.google.android.play.core.common.PlayCoreDialogWrapperActivity`, `com.pairip.licensecheck.LicenseActivity`

**Activity-aliases (launcher):**

| Alias | Enabled | Icon | Purpose |
|---|---|---|---|
| `com.alexter.dota2helper.GoldIconAlias` | `true` | `@mipmap/ic_launcher_gold` | Default launcher |
| `com.alexter.dota2helper.ClassicIconAlias` | `false` | `@mipmap/ic_launcher_classic` | Swapped on demand by `AppIconModule` |

Both target `com.alexter.dota2helper.MainActivity`; `AppIconModule` flips `enabled` at runtime to change the launcher icon.

**Manifest `<meta-data>` (selected):**

| Key | Value |
|---|---|
| `expo.modules.updates.ENABLED` | `true` |
| `expo.modules.updates.EXPO_RUNTIME_VERSION` | `@string/expo_runtime_version` (= `1.6.4`) |
| `expo.modules.updates.EXPO_UPDATES_CHECK_ON_LAUNCH` | `WIFI_ONLY` |
| `expo.modules.updates.EXPO_UPDATES_LAUNCH_WAIT_MS` | `0` |
| `expo.modules.updates.EXPO_UPDATE_URL` | `https://u.expo.dev/e36186af-6040-4910-adad-3efc2fb0808f` |
| `io.appmetrica.analytics.plugin_id` | `react-native-4.0.0` (RN bridge plugin) |
| `console_app_id_value` | `@string/rustore_console_app_id` |
| `sdk_pay_scheme_value` | `@string/rustore_pay_scheme` |
| `com.android.stamp.source` | `https://play.google.com/store` (Google Play distribution stamp) |
| `com.android.stamp.type` | `STAMP_TYPE_DISTRIBUTION_APK` |
| `com.android.vending.splits` | `@xml/splits0` (ABI/density splits) |
| `org.unimodules.core.AppLoader#react-native-headless` | `expo.modules.adapters.react.apploader.RNHeadlessAppLoader` |
| `com.facebook.soloader.enabled` | `true` |

**`<queries>` block** (package visibility): `VIEW` + `BROWSABLE` on `https`, `OPEN_DOCUMENT_TREE`, `android.support.customtabs.action.CustomTabsService` — i.e. it can open custom-tab browsers (the premium checkout) and pick documents.

**`<uses-library android.ext.adservices" required="false">`** — Android Privacy Sandbox ad-services is optional, consistent with the ads SDK being absent.

**Deep-link schemes on `MainActivity`:**
`dota2helper://` · `com.alexter.dota2helper://` · `exp+dota2helper://` · `dota2helper.rustore.pay://`

**Services:** Firebase `ComponentDiscoveryService` (with 9 component registrars), `io.appmetrica.analytics.internal.AppMetricaService`, `androidx.room.MultiInstanceInvalidationService`, `androidx.credentials.playservices.CredentialProviderMetadataHolder`, `com.google.android.gms.measurement.AppMeasurementService` / `AppMeasurementJobService`, GMS `RevocationBoundService`

**Providers:** `RNCWebViewFileProvider` (`….fileprovider`), `ReactNativeFirebaseAppInitProvider`, `AppMetrica PreloadInfoContentProvider`, `expo.modules.filesystem.FileSystemFileProvider`, `com.google.firebase.provider.FirebaseInitProvider`, `androidx.startup.InitializationProvider`

**Receivers:** `AppMeasurementReceiver`, `ProfileInstallReceiver`

---

## 3. How the app works

### 3.1 Boot sequence

1. Android instantiates `com.pairip.application.Application`
2. `LicenseClient.checkLicense(context)` in `attachBaseContext` → **PairIP license/DRM gate** (fails closed)
3. `MainApplication.onCreate` → `SoLoader.init(...)` (loads Hermes + native `.so`), `ApplicationLifecycleDispatcher.onApplicationCreate(this)`
4. `MainActivity.onCreate` → Expo splash registered, `super.onCreate(null)`, reflective RuStore intent
5. RN host starts Hermes on `assets/index.android.bundle` (48.8 MB)
6. expo-router resolves the initial route → `app/index.tsx` → redirects to `app/(tabs)/home.tsx`

### 3.2 Data flow — the key architectural insight

The app is **offline-first with remote patching**.

**Bundled (Metro-inlined `require()`'d JSON):**

| Path pattern | Contents |
|---|---|
| `./formatted_<lang>/<entityId>.json` | Per-language, per-entity formatted data: heroes, items, abilities, creeps, buildings, buffs, talents |
| `./guidesData/<lang>/index.json` | Guide index per language |
| `./camps.json` | Neutral/lane camp definitions |
| `./creepNames.json` | Creep display names |
| `./abilityLevels.json` | Per-level ability value tables |
| `./extraAbilities.json` | Additional ability records |
| `./shortItems.json`, `./heroes/short.json` | Compact list-view schemas |
| `./unitExtras.json` | Unit metadata |

**Languages observed in the data matrix:** `english`, `german`, `russian`, `spanish`, `portuguese`, `indonesian`, `schinese`, `ukrainian`, `japanese` (and others).

**Source of truth is Valve's game KV files** — the app even ships a provenance hash:

```
Valve KV npc_abilities.txt SHA-256 040b8075832a8c5767bb2ad50ca5eb1dfda024a9c45d1d5b857d2911f2d97ab89d1c57
```

**Gameplay tables referenced by Valve's own keys:**
`items_core` · `items_ad` · `items_neutral` · `items_runes` · `npc_abilities` · `npc_heroes` · `npc_units` · `special_bonus_*` · `pc_dota_hero_*` · `building_2 … building_16` · `bunker_units` · `burn_dps_buildings` · `burn_dps_units` · `burn_tickrate`

**Runtime remote content:** AsyncStorage key `@dota2helper_remote_content_v1` holds a downloaded patch snapshot; `checkForUpdates` and a `"Next update {date}"` string indicate a delta-fetch mechanism layered on top of the bundled data.

**Icons and videos are NOT bundled — they stream from Valve's CDN:**

```
https://cdn.steamstatic.com/apps/dota2/images/dota_react/items/<item>.png
https://cdn.akamai.steamstatic.com/apps/dota2/images/dota_react/abilities/<ability>.png
https://cdn.akamai.steamstatic.com/apps/dota2/videos/dota_react/abilities/<hero>/<ability>.webm
```

Ability demo videos are played with `expo-video` (`expo.modules.video.FullscreenPlayerActivity`, PiP enabled).

### 3.3 Backends & third-party services

| Host | Purpose | Evidence |
|---|---|---|
| `https://api.dota2helper.pro` | Own backend — **live** (HTTP 404 JSON `{"error":"Not found"}` at root) | Endpoints: `/api/player-profile`, `/api/surveys/?token=`, `/batch/array`, `/players` |
| `https://api.opendota.com/api/patchnotes` | Patch notes feed | `library/patch-notes.tsx` |
| `https://www.opendota.com/assets/images/dota2/rank_icons/…` | Rank icons (Herald → Immortal) | Profile / rank display |
| Firebase (Analytics 22.4.0, Auth 23.2.0, Firestore, Installations) | Identity, surveys, event log | `google_storage_bucket = dota-2-helper-app-web.firebasestorage.app`, `google_app_id = 1:778448490117:android:5e6531666b6e7e059763ec`, `gcm_defaultSenderId = 778448490117` |
| Yandex AppMetrica | Analytics SDK (2,086 classes) | `reportAppMetricaEvent`, `AdRevenue`, `AdUnitId` |
| PostHog | Analytics **+ remote config / feature flags** | `posthog-rn.json`, `/i/v1/logs?token`, `parsePostHogCookie_remoteConfigResponsePromise`, `KnownFeatureFlags`, `resetPersonPropertiesForFlags`, `disableRemoteFeatureFlags` |
| Steam | OpenID account linking | `steam-callback.tsx`, `buildSteamOpenIdUrl`, `parseSteamStartParam`, `parseUserinfoText`, `parseSteamCallback_angle` |
| EAS Update | OTA JS updates | `u.expo.dev/e36186af-…`, `checkForUpdates` |
| Google Sign-In | Firebase Auth | `default_web_client_id = 778448490117-s7aio6rgb9n4sp796fr6jhm4p0en9262.apps.googleusercontent.com` |
| Telegram | Deep link to a bot | `https://t.me/tribute/app?startapp=dlys` |
| flycricket.io | Hosted privacy policy / terms | `doc-hosting.flycricket.io/dota-2-helper-s-privacy-policy/…` |
| `https://dota2helper.app/premium` | Web checkout (did not resolve at analysis time) | premium strings |
| `http://yandex.com/bots` | Yandex ads (code path only) | bundle string |
| Liquipedia / dotawiki.de / wikiwiki.jp / invokergame.org / steamcommunity / reddit | **Guide source citations** | `assets/pictures/guideSources/icon-{opendota,steam,stratz}.png` |

### 3.4 Storage & persistence

- **AsyncStorage** — `@dota2helper_remote_content_v1`, `adPersistedSnapshot`, `ProfileMediaCache`, `preloadedRoutes`
- **Firestore** — `collection()`, `doc()`, `getDoc()`, `getDocs()`, `setDoc()`, `addDoc()`, `updateDoc()`, `where()`, `orderBy()`; features `ActiveMatchingSurveys`, `SURVEY_LANGUAGE_PROPERTY`, `ReportEvent`; cache invalidation on account change (*"result stale (account changed), ignored"*)
- **Firebase Auth** — Google Sign-In, GenericIdp, reCAPTCHA
- **SQLite / Room** — `androidx.room.MultiInstanceInvalidationService` (transitively via AppMetrica / Firestore)
- **expo-file-system** — cached media and offline content
- **expo-secure-store** — *not present*

### 3.5 Analytics / telemetry

AppMetrica + Firebase Analytics + PostHog, with events such as `checkout_started`, `ReportEvent`, `adPersistedSnapshot`, `reportAppMetricaEvent`, `adRevenue`, `ScreenStackItem`. PostHog doubles as a **remote-config / feature-flag** channel (`KnownFeatureFlags`, `featureflags/index.js`).

### 3.6 Monetization

**Ads — disabled in this build.**
`extra.ads.enabled = false`, `provider: "none"`, no Yandex Ads SDK (`ru.ydn` = 0 classes), no AdMob UI (only `play-services-ads-identifier` for the ID). The JS still contains the ad surface (`bannerPremium`, `AdUnitId`, `bannerWrapper`, placements `home,library`), so ads are toggled by config / remote flag.

**Premium — web-checkout subscription, not Play Billing.**

| String | Meaning |
|---|---|
| `Premium subscription active_duration_day_…` | Active entitlement |
| `Premium suspended` | Past-due / paused |
| `Premium disabled` | Revoked |
| `CancelPayment error, subscription paused. Check your card` | Payment failure |
| `CancelPayment failed. Check your card/balance` | Payment failure |
| `Payments are almost ready. Premium purchases will be available in an upcoming update.` | **Play build: not yet purchasable** |
| `premium_entitled`, `premium-check`, `hasPremiumAccess`, `preview-premium` | Entitlement flags |
| `premiumRow`, `premiumIcon`, `premiumWidth`, `premiumPreview` | Paywall UI |

Checkout uses `expo-web-browser` / `react-native-webview` against `https://dota2helper.app/premium`. Analytics event `checkout_started` fires on entry.

**RuStore payment** — implemented in code but reflectively loaded and **absent from this Google Play build** (0 `ru.rustore.*` classes). Enabled per build flavor via `storeChannel`.

---

## 4. Feature-by-feature

### 4.1 Navigation map (expo-router, 5 tabs)

```
app/
├── _layout.tsx                     root layout (expo-router, deep links)
├── index.tsx                       → redirects to (tabs)/home
├── +not-found.tsx                  404
├── paywall.tsx                     premium upsell
├── profile-stats.tsx               player statistics (OpenDota)
├── steam-callback.tsx              Steam OpenID OAuth callback
├── dev/
│   ├── personal-advice.tsx         dev-only screen
│   └── profile-premium.tsx         dev-only screen
└── (tabs)/
    ├── _layout.tsx                 tab bar
    ├── home.tsx                    HOME
    ├── heroes/   _layout.tsx, index.tsx, [id].tsx
    ├── items/    _layout.tsx, index.tsx, [id].tsx
    ├── picker/   _layout.tsx, index.tsx, heroes/[id].tsx
    ├── profile.tsx                 PROFILE
    └── library/
        ├── _layout.tsx, index.tsx
        ├── heroes/   index.tsx, [id].tsx
        ├── items/    index.tsx, [id].tsx
        ├── creeps/   index.tsx, [id].tsx
        ├── guides/   index.tsx, [id].tsx
        │   └── test/ [id].tsx, result/[id].tsx       ← quiz engine
        ├── dota1/
        │   ├── heroes/ index.tsx, [id].tsx
        │   └── items/  index.tsx, [id].tsx
        ├── map/index.tsx                            ← interactive Dota map
        ├── patch-notes.tsx                          ← OpenDota patch notes
        └── dev-personal-advice.tsx
```

*(All 31 route paths were recovered verbatim from the Hermes string table.)*

### 4.2 Tab: **Home**

Entry screen. Carries the ad slot (`placements: "home"`), remote-content / patch banner, and navigation into library sections.

Supporting assets: `assets/bg-dota-helper`, `assets/icons/`, `assets/pictures/helperScreens/*` (`main-card`, `attributes-card`, `atributes-card`, `health-card`, `mana-card`, `level-card`, `bottom-card`, `middle-card`, `top-card`).

### 4.3 Tab: **Heroes** (Dota 2) — `heroes/index`, `heroes/[id]`

Per-hero reference pages:

- **Attributes** — STR / AGI / INT / universal (filter icons `IconsFilterHeroes/{agility,intelligence,strength,universal}`)
- **Combat stats** — attack damage, attack range, attack rate, armour, movement speed, HP/Mana, DPS. Card artwork: `bg-hero`, `bg-name`, `bg-health`, `bg-mana`, `icon-armor`, `icon-attack_range`, `icon-attack_rate`, `icon-damage`
- **Abilities** — full ability list with per-level values (`abilityLevels.json`), damage type, mana cost, cooldown, cast range, and the talent tree (`talants-tree`, `talants-tree-small`, `bg-talents`, `bg-talents-first`, `Icons/talent_check`)
- **Facets** (Dota 2 hero variants) — `facet_abilities`, `facet_bonus_values_formattedByLangAnd`, `facetSections`, `facet_localData`; e.g. `pc_dota_hero_skeleton_king_facet_cursed_blade`, `dazzle_facet_nothl_boon`, `special_bonus_unique_wraith_king_facet_1`
- **Aghanim's** — Scepter + Shard variants (`aghanim-scepeter`, `aghanim-shard`, `innate-ability`, `mana-icon`, `range-icon`, `reload-icon`)
- **Ability demo videos** — streamed `.webm` from the Valve CDN, played with `expo-video`
- **Patch-note deltas** — inline changelog rows comparing current vs. previous values, e.g. *"Base Agility decreased from 23 to 21"*, *"Bonus lifesteal reduced from +24% to +22%"*, *"Talent Level 25 Bonus Curiosity reduced from 2x to 1.5x"*
- Hero lore text (full biographies, localized — e.g. Aiushtha, Alchemist, Witch Doctor, Slark)

### 4.4 Tab: **Items** — `items/index`, `items/[id]`

- Cost, stats, recipe tree (`recipe_*` entity ids in the data, e.g. `recipe_abyssal_blade`, `recipe_aghanims_scepter`)
- Active / passive ability text, charges, components
- Neutral items, runes
- Same patch-delta rendering as heroes
- Icons: `assets/pictures/ItemIcons` (12) + Valve CDN item images

### 4.5 Tab: **Picker** (hero draft assistant) — `picker/index`, `picker/heroes/[id]`

- Hero grid with role/attribute filters:
  `block_Carry`, `block_Support`, `block_Nuke`, `block_Control`, `block_Pusher`, `block_Item`, `block_AttackSpeed`, `block_AttackRate`, `block_MagicResistance`, `block_MovementSpeed`, `block_ProjectileSpeed`, `block_TurnRate`, `block_VisionRange`
- Hero detail pages in picker context
- **"Saved picker builds"** — user-persisted draft builds (AsyncStorage)
- Assets: `assets/picker/png` (18), `selectHeroesContainer`, `blockTitleText`

### 4.6 Tab: **Profile** — `profile.tsx`, `profile-stats.tsx`

- **Account linkage:** Google Sign-In (Firebase Auth) and **Steam OpenID** (own OAuth callback screen)
- **OpenDota player dashboard** — the richest live-data feature:
  - `dashboard-full-width-tabs`
  - `dashboard-hero-lifetime-scope`
  - `dashboard-hero-role-scope`
  - `dashboard-legend-role`
  - `dashboard-match-contour`
  - `dashboard-match-date`, `dashboard-match-time`, `dashboard-match-details`, `dashboard-match-numbers`
  - *"Account totals and hero statistics cover all available history. Role distribution is based on the last 50 matches."*
  - Match list with role/percentage breakdown per game; *"play five more games"* prompts; *"Meta de scale: partidas fica mais longas"*
  - `PropendotaGuideCard`, `PropendotaTitle`, `PropendotaWatermarkExpired` → the **OpenDota "pro" API is a premium-gated feature** (watermark when not entitled)
- **Premium upsell entry points:** `preview-profile-analytics-entry`, `profile-rating-entryPoints`
- **Personal advice / assistant** — *"Access to the personal assistant. Finish setting up your profile to use Premium recommendations."* (premium-gated; dev route `dev-personal-advice.tsx`)
- Analytics assets: `assets/profile/analytics/{avatar-flame-steam, profile-background, wraith-header}`

### 4.7 Library — `library/index.tsx`

Hub for: **Heroes**, **Items**, **Creeps**, **Guides**, **Map**, **Patch Notes**, plus a **Dota 1** section (gated by `extra.dota1.enabled`).

#### Library → Heroes / Items

"Reference library" variants of the hero/item pages with richer data, plus the **Dota 1** sub-tree (`library/dota1/heroes`, `library/dota1/items`) covering the original Dota 1 roster (Ringmaster, Lifestealer, Axe, Necrolyte, Sand King … — confirmed by bundled hero/ability lore text).

#### Library → Creeps — `creeps/index`, `creeps/[id]`

Dota 2 neutral + lane creep encyclopedia:

| Asset folder | Count | Contents |
|---|---|---|
| `assets/creeps/units` | 71 | Creep portraits |
| `assets/creeps/abilities` | 66 | Per-creep ability icons |
| `assets/creeps/tiles` | 7 | Map tiles for creep spawn zones |
| `assets/creeps/chips` | 6 | Melee / ranged / siege lane-creep chips, Radiant + Dire variants |
| `assets/creeps/pairs` | 5 | Creep-pair compositions (melee/ranged/siege × lane, incl. mega) |
| `assets/creeps/ui` | 3 | Flagbearer badge, reward gold, reward XP |

Data: `creepNames.json`, `unitExtras.json`, `camps.json`.
Attribution shipped in-app: *"Creep-Bilder: Liquipedia (CC BY-SA 3.0)"*.

#### Library → Guides — 29 authored topics

| Category | Guide slugs |
|---|---|
| Onboarding | `intro`, `heroes_intro`, `troubleshooting`, `linking` |
| Fundamentals | `map_overview`, `laning`, `laning_mechanics`, `roles_positions` |
| Farming | `lasthit_farm` |
| Warding | `warding_overview`, `warding_mastery`, `warding_tactics` |
| Runes | `rune_work` |
| Team play | `team_communication`, `communication_strategy` |
| Draft / scouting | `draft_synergy`, `opponent_analysis`, `meta_understanding` |
| Mechanical | `micro_macro_control`, `macro_game`, `resource_management` |
| Improvement | `error_analysis`, `fight_strategies`, `flexible_builds` |
| Psychology | `psychology` |
| Dota 2 HUD | `ui_controls` |

- Illustrations in `assets/guides/<topic>/*.png`, e.g.
  - `map_overview/{barracks, fog_day_night, full_map, jungle_and_river, fountain, lanes, lotus_pool, megacreeps, outposts, roshan_pit, shops, sides, tormentor, towers, twin_gates, watcher}.png`
  - `rune_work/rune_{arcane, double_damage, haste, illusion, invisibility, shield, water}.png`
  - `lasthit_farm/{catapult, creep_aggro, denying, farm_after, farm_lane, jungle_creeps, quelling_blade, stacking, tower_lasthit}.png`
  - `warding_overview/{deward, gem_dust_watcher, observer_vs_sentry, positioning, ward_spots}.png`
  - `warding_mastery/{deward, vision_stages}.png`
  - `roles_positions/{heroes_by_position, positions_map}.png`
  - `meta_understanding/{tier_lists, tempo_scale}.png`
  - `opponent_analysis/power_windows.png`, `psychology/toxic_chat.png`, `team_communication/{chat_wheel, cover, mute_panel, pings}.png`
- `assets/guides/ui_controls/*` are **.web WebP walkthroughs of the Dota 2 HUD**: `ui_additional_1`, `ui_audio_add_1`, `ui_audio_overview`, `ui_camera_1`, `ui_camera_hotkeys`, `ui_chat_1`, `ui_display_1`, `ui_display_2`, `ui_game_settings`, `ui_hero_unit_1`, `ui_interface_healthbars`, `ui_interface_hotkeys`, `ui_minimap_1`, `ui_output_1`, `ui_output_2`, `ui_quickcast_1`, `ui_render_1/2/3`, `ui_video_overview`, `ui_volume_1` — with localized narration strings (Indonesian *"Sembunyikan"*, *"Menembakkan"*; Spanish *"Seleccionar"*; Russian *"Выберите"*)
- **Quiz engine** — `library/guides/test/[id].tsx` → `library/guides/test/result/[id].tsx`: per-guide multiple-choice questions with `DisplayOrder`, `Question`, `sumText`, `ActiveMatchingSurveys`; finish artwork `assets/pictures/articles/quizFinish/{left-1, left-2, right-1, right-2, logo-main}`
- **Source citations are first-class** — `assets/pictures/guideSources/icon-{opendota, steam, stratz}.png` plus outbound links to `opendota.com`, `steamcommunity.com/sharedfiles`, `liquipedia.net/dota2/Creeps`, `wikiwiki.jp/dota2/Glossary`, `dotawiki.de`, `invokergame.org/uk`, `reddit.com/r/russian/…`
- Guide content is per-language: `guidesData/<lang>/index.json` (english, spanish, german, indonesian, russian, chinese, japanese, …)

#### Library → Map — interactive Dota 2 map

Built from **Figma-exported vector layers**:

`assets/map/figma/` (29 layers): `camp_ancient`, `camp_large`, `camp_medium`, `camp_medium_water`, `camp_small`, `camp_small_water`, `fountain`, `general_radiant`, `general_dire`, `misc_radiant`, `misc_dire`, `racks45_radiant`, `racks45_dire`, `racks90_radiant`, `racks90_dire`, `roshan`, `rune_bounty`, `rune_power`, `shop_house`, `shop_tent`, `tormentor_radiant`, `tormentor_dire`, `tower_big_radiant`, `tower_big_dire`, `tower_radiant`, `tower_dire`, `twin_gate`, `watcher`, `wisdom`

`assets/map/styles/` (3 render presets): `minimal`, `realistic`, `screen-bg`

Tappable zones: camps, towers, shops, runes, Roshan pit, Tormentor, Twin Gates, Fountain, Wisdom runes. Route/building data from `building_2..16`, `bunker_units`, `burn_dps_*`, `burn_tickrate`.

#### Library → Patch Notes

Renders `https://api.opendota.com/api/patchnotes`; anchored via `PatchNotesAnchors`; error state *"Saved patch notes could not be loaded. Please open this page again later."*

### 4.8 Premium / Paywall — `app/paywall.tsx`

- Flags: `premium_entitled`, `premium-check`, `hasPremiumAccess`, `preview-premium`
- UI: `premiumRow`, `premiumIcon`, `premiumWidth`, `premiumPreview`
- Assets: `assets/premium` (10 images)
- Gated content: **personal assistant (AI advice)**, **OpenDota "Pro" API (propendota)**, **profile analytics**, *"Access to upcoming premium features"*
- Subscription state machine: `active_duration_day_…` → `suspended` → `disabled`
- In this Play build: *"Payments are almost ready. Premium purchases will be available in an upcoming update."* — the purchase UI points at the web checkout

### 4.9 Other features

| Feature | Evidence |
|---|---|
| **Dynamic launcher icon** (`classic` ↔ `gold`) | `AppIconModule`, `GoldIconAlias` |
| **Deep linking** | schemes `dota2helper://`, `com.alexter.dota2helper://`, `exp+dota2helper://`, `dota2helper.rustore.pay://`; `parsePathAndParamsFromExpoGoLinking` |
| **Localization** — 9 UI languages | `assets/lg/{us, gr, ind, jp, pt, ru, sp, ukr, ch}`; `expo-localization`; `detectUserLanguage`; `SURVEY_LANGUAGE_PROPERTY` |
| **Surveys** (Firestore, language-targeted) | `ActiveMatchingSurveys`, `surveys/validationErrorText` |
| **Onboarding video** | `res/raw/assets_bgdotahelper.mp4` (871,408 B) |
| **Typography** | Lato (Black/Bold/Heavy/Medium/Regular) + Philosopher (Regular/Bold/Italic/BoldItalic) — 9 font files |
| **Theme** | Dark only (`userInterfaceStyle: "dark"`, `#000000` background) |
| **Cross-promotion / affiliate** | `extra.ads.offer = { id: "demo-gaming-gear", source: "affiliate", destinationUrl: "https://market.yandex.ru/" }` |
| **PiP video** | `expo.modules.video.FullscreenPlayerActivity` |

---

## 5. Data model (for a clone)

```
Heroes      npc_dota_hero_<name>    attributes, stats, abilities[], facets[], talents[], aghs, cosmetics
Abilities   <hero>_<ability>        per-level values, mana, cooldown, range, damage type, video URL
Items       item_<name>             cost, stats, actives/passives, recipe tree, charges
Recipes     recipe_<item>           component graph
Creeps      npc_dota_<creep>        model, abilities, spawn camps, lane, rewards
Camps       camp_<size>             position, type, timing, neutrals
Buildings   building_<2..16>        towers/barracks/racks, HP, armour
Buffs       special_bonus_*         talent/unique modifiers
Runes       rune_*                  power/bounty/water/etc.
Map         map/figma/*              layer assets + 3 styles
Guides      guides/<slug>           content, images[], quiz[], sources[]
```

**Localization matrix:** `formatted_<lang>/<entityId>.json` for every entity × every language — this is the bulk of the 48.8 MB bundle.

**Entity counts from the asset manifest:**

| Folder | Count |
|---|---|
| `assets/dota1/abilities` | 461 |
| `assets/dota1/heroes` | 221 |
| `assets/dota1/items` | 141 |
| `assets/creeps/units` | 71 |
| `assets/creeps/abilities` | 66 |
| `assets/map/figma` | 29 |
| `assets/guides/*` | 126 (across 29 topics) |
| `assets/pictures/*` | 74 |
| `assets/map/styles` | 3 |
| `assets/premium` | 10 |
| `assets/fonts` | 9 |
| `assets/lg` | 9 |
| `assets/library` | 7 |
| `assets/profile/analytics` | 3 |

---

## 6. Clone blueprint

> **Legal note.** The app's code, brand, and bundled content are the developer's IP. Valve's KV game files and the Steam CDN are licensed assets, and the original app itself carries attribution obligations (Liquipedia CC BY-SA 3.0, plus links to Valve / OpenDota / Stratz). Build your own implementation against public and properly-attributed sources rather than shipping their assets or brand. PairIP is a commercial third-party product — do not copy `com.pairip.*`.

### Step 1 — Scaffold

```bash
npx create-expo-app dota-helper
# Expo SDK 53, expo-router, TypeScript, Hermes enabled
```

```jsonc
// app.config.ts
{
  "expo": {
    "sdkVersion": "53.0.0",
    "android": { "package": "com.your.dota2helper", "versionCode": 1 },
    "plugins": [
      "@react-native-firebase/app",
      "expo-updates",
      "expo-localization",
      ["expo-build-properties", { "android": {
        "buildToolsVersion": "36.0.0",
        "compileSdkVersion": 36,
        "targetSdkVersion": 36 } }]
    ],
    "extra": { ads: { enabled: false }, premium: { enabled: false }, dota1: { enabled: true } }
  }
}
```

Pin the toolchain to match the original: **Kotlin 2.0.21 · Gradle 8.13 · JVM target 17 · Hermes on · New Architecture off**.

### Step 2 — Data pipeline

1. Pull Valve's KV (`npc_heroes`, `npc_abilities`, `npc_units`, `items_core`, `items_ad`, `items_neutral`, `items_runes`).
2. Convert to per-entity JSON; keep a `sourceSha256` field for provenance (the original ships `npc_abilities.txt SHA-256 040b8075…`).
3. Emit two schemas: a **short** list-view schema and a **full** detail schema.
4. Generate the per-language matrix `formatted_<lang>/<id>.json`.

### Step 3 — Content delivery (mirror the original's split)

- Bundle short data for instant offline reads
- Ship per-language detail either in-bundle or lazily
- Stream icons from the same Valve CDN paths; cache with `expo-file-system`
- Keep a versioned remote-content key (e.g. `@<app>_remote_content_v1`) in AsyncStorage and apply deltas from your backend

### Step 4 — Navigation

Reproduce the 5-tab + library tree:

```
app/(tabs)/{home, heroes, items, picker, profile, library}
app/(tabs)/library/{heroes, items, creeps, guides, guides/test, map, patch-notes, dota1/*}
app/{paywall, profile-stats, steam-callback, +not-found}
```

### Step 5 — Guides + quiz

Content model:

```jsonc
{ "slug": "laning", "lang": "en", "title": "…", "body": "…",
  "images": [{ "src": "guides/laning/creep_block", "caption": "…" }],
  "sources": [{ "label": "OpenDota", "icon": "opendota", "url": "https://…" }],
  "quiz": [{ "order": 1, "question": "…", "options": ["…"], "answer": 0 }] }
```

Wire `guides/test/[id]` → `guides/test/result/[id]`.

### Step 6 — Map

Import Figma layers, author interactive zones (camp / tower / shop / rune / Roshan / Tormentor / Twin Gate / Fountain / Wisdom), ship 2–3 style presets (`minimal`, `realistic`, `screen-bg`).

### Step 7 — Live features

- OpenDota `/api/player-profile`, `/players`, `/api/patchnotes`
- Steam OpenID for account linking (`steam-callback` route)
- Your own backend for `/api/surveys`, the event log, and remote content

### Step 8 — Monetization

- Start with ads off; implement real Play Billing (`com.android.billingclient`) or a web checkout
- Define one entitlement flag (`premium_entitled`) and gate the assistant + pro-endpoints on it
- Handle `active` / `suspended` / `disabled` states explicitly

### Step 9 — Platform services

Firebase (Analytics / Auth / Firestore) + PostHog (analytics + remote feature flags) + AppMetrica if targeting RU. Enable EAS Update with a `runtimeVersion` and `checkAutomatically: "WIFI_ONLY"`.

### Step 10 — Native extras (optional)

`AppIconModule` for dynamic icons (activity-alias pair), keep `usesCleartextTraffic="false"`, add `expo-video` PiP for ability demos.

### Step 11 — Protection

Instead of PairIP: Play App Signing + **Play Integrity API** + R8/ProGuard + emulator/root detection. Do not copy `com.pairip.*`.

### Step 12 — Localization

Ship 9 locales from the start (`en, es, pt, ru, uk, el, id, ja, zh`) — the data matrix is the expensive part, not the UI.

---

## 7. Evidence, coverage & limitations

### Tooling note

REA's own Android provider was initially unavailable:

```
capability_unavailable / unsupported_provider
"Set REA_JADX_MCP_JAR to the absolute path of a caller-supplied
 jadx-headless-mcp 0.7.1 JAR. REA does not download or install it."
diagnostics: { jar_configured: false, failure_kind: "jar", failure_code: "not_configured" }
```

**Root cause (not a missing JAR):** the JAR was already present at
`C:\Users\Henry\.local\share\rea\android\jadx-headless-mcp-0.7.1-all.jar`
(SHA-256 `6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`),
and `opencode.json` already declared it — but under the key **`env`** instead of
**`environment`**. OpenCode's `McpLocalConfig` schema
(`https://opencode.ai/config.json`) defines the property as `environment` with
`additionalProperties: false`, so the `env` block was **silently dropped** and
the variable never reached the REA server process. Renaming the key to
`environment` resolved it; REA's `inspect_android_package` then succeeded
against the same APK with `provider: { id: "jadx", version: "0.7.1" }`, and
returned complete decoded-manifest Evidence.

Both the Android analysis and the archive inventory were then performed through
**REA itself** (`open_binary` → `format: "apk"`, `kind: "archive"`,
`sha256: 4fbd8479…`; `inspect_android_package` → `ev_c1766d165feededaace523b929cd78f4f62440313b296c32aa065df2bcdaea17`).
The separately-connected **`jadx-headless`** provider was used for the
class-level decompilation sweep (20,568 classes, `code_cache_size: 0`,
`threads: 0`, `resources: "full"`).

**Applied configuration** (`C:\Users\Henry\.config\opencode\opencode.json`):

```jsonc
"rea": {
  "type": "local",
  "command": ["cmd.exe","/d","/c","npx","-y","rea-agents@6.7.0","mcp"],
  "enabled": true,
  "environment": {                          // was "env" — silently ignored
    "REA_JADX_MCP_JAR": "C:\\Users\\Henry\\.local\\share\\rea\\android\\jadx-headless-mcp-0.7.1-all.jar",
    "JAVA_HOME": "C:\\Program Files\\Java\\jdk-25.0.4.1",
    "REA_JADX_OPERATION_TIMEOUT_MS": "300000"
  },
  "timeout": { "startup": 120000, "catalog": 60000, "execution": 300000 }
}
```

> **Note:** the REA MCP server process is spawned at OpenCode startup. After editing the config the client must be **restarted/reconnected** for the new environment to take effect. The `timeout` block was raised from the 5,000 ms default because a JADX APK load alone takes ~10 s on this artifact and per-operation decompiles can reach the 90–300 s deadline.

### Observed (high confidence)

- Manifest declarations, permissions, all components
- All 6 DEX class trees; native Kotlin sources for `MainActivity`, `MainApplication`, `AppIconModule`, `BuildConfig`, `com.pairip.application.Application`
- Gradle / Kotlin / Firebase versions from embedded metadata (`kotlin-tooling-metadata.json`, `*.properties`)
- All 1,302 Expo asset entries (names, subdirectories, packager hashes)
- All 31 expo-router route paths
- The 29 guide slugs
- The API host `https://api.dota2helper.pro` — **live-probed** (HTTP 404 JSON at root)
- Valve CDN URL patterns
- The 9-language set
- The 48.8 MB Hermes string table (via UTF-16-aware scanning)
- `res/values/strings.xml` (337 entries) including `google_storage_bucket`, `google_app_id`, `gcm_defaultSenderId`, `default_web_client_id`, `google_api_key`

### Derived (medium confidence)

- Exact JS function bodies and the precise per-string boundaries inside the Hermes string table. No Hermes **bytecode** disassembler was available on this host: the npm package `hermes-parser` is a *JavaScript-source* parser (Babel-style AST), not a bytecode reader, and no `hermes-dec` / `hbctool` build exists for Windows here. The string pool was recovered by UTF-16-aware scanning, so adjacent literals are concatenated in the raw extracts. **Every string quoted in this report was individually re-verified** by regex or byte offset before inclusion.
- Feature semantics are read from that pool, cross-checked against the asset manifest and the native code.

### Unknown / not established

- Server-side implementation of `api.dota2helper.pro`
- Exact PostHog flag names and values
- Which ad SDK is used when `ads.enabled = true` (no ad SDK is bundled in this build, so the ad path is compiled but inert)
- Whether premium purchase completes in production (the Play build's own string says payments are not yet available there)
- True state of `dota2helper.app` (did not resolve at analysis time)
- Whether the Dota 1 content gate uses the same remote flag as `extra.dota1.enabled`

### Not observed

No execution, no emulator, no network capture — **the APK was never launched**. All runtime behavior above is inferred from static artifacts, manifest declarations, and decompiled code.

### Reproducibility

| Artifact | Path |
|---|---|
| APK | `Helper Dota 2.apk` |
| Extracted archive | `%TEMP%\opencode\apk_extract` |
| Extracted strings | `%TEMP%\opencode\hbc\strings_all.txt` |
| Extraction scripts | `%TEMP%\opencode\hbc\{extract.js, probe.js, strings16b.js, findtable.js, ctx.js, re.js}` |

Useful commands:

```bash
# decode manifest / class list
jadx-headless.load_apk({ path: "<apk>", code_cache_size: 0, threads: 0, resources: "full" })
jadx-headless.get_android_manifest({ section: "activities" })

# recover the Hermes string pool (UTF-16 aware)
node strings16b.js assets/index.android.bundle strings_all.txt

# regex-mine the pool for routes, endpoints, asset paths
node re.js strings_all.txt "routes::\.\/\(tabs\)\/[a-zA-Z0-9_\-\[\]\/\(\)]*"
```

---

## Appendix A — Enabling REA's Android (JADX) provider

REA's Android tool family (`inspect_android_package`, `search_android_classes`,
`inspect_android_class`, `inspect_android_method`, `trace_android_references`)
is gated on a **caller-supplied** JADX MCP JAR. REA never downloads or installs
it, and `rea doctor` does not cover the JADX scope (it covers Hopper/Ghidra).

### A.1 Prerequisites

| Requirement | Notes |
|---|---|
| `jadx-headless-mcp` **0.7.1** JAR | `Main-Class: com.atxx.jhmcp.MainKt`, shaded "all" build |
| Java 17+ | JDK 21/25 recommended; a **full JDK** is required (needs `jdk.compiler`) |
| Windows x64 | Requires the matching bundled native controls; REA uses an owned Job Object with bidirectional stdio |
| `jdk.compiler` present | A JRE-only install fails |

Verify the JAR runs standalone before pointing REA at it:

```bash
java -jar jadx-headless-mcp-0.7.1-all.jar
```

### A.2 Environment variables

| Variable | Purpose |
|---|---|
| `REA_JADX_MCP_JAR` | **Absolute path** to the 0.7.1 JAR |
| `JAVA_HOME` | Selects the JDK; on Windows REA uses `$JAVA_HOME\bin\java.exe` |
| `REA_JADX_HEAP_MIB` | JVM heap for the worker (default 3934 MiB observed) |
| `REA_JADX_OPERATION_TIMEOUT_MS` | Per-operation deadline (default 120000 ms) |

### A.3 OpenCode configuration (this machine)

`C:\Users\Henry\.config\opencode\opencode.json`:

```jsonc
{
  "mcp": {
    "rea": {
      "type": "local",
      "command": ["cmd.exe", "/d", "/c", "npx", "-y", "rea-agents@6.7.0", "mcp"],
      "enabled": true,
      "environment": {
        "REA_JADX_MCP_JAR": "C:\\Users\\Henry\\.local\\share\\rea\\android\\jadx-headless-mcp-0.7.1-all.jar",
        "JAVA_HOME": "C:\\Program Files\\Java\\jdk-25.0.4.1",
        "REA_JADX_OPERATION_TIMEOUT_MS": "300000"
      },
      "timeout": { "startup": 120000, "catalog": 60000, "execution": 300000 }
    }
  }
}
```

> ⚠️ The property name is **`environment`**. OpenCode's `McpLocalConfig` schema
> (`https://opencode.ai/config.json`) declares it with `additionalProperties: false`,
> so using `env` is **silently ignored** — the REA server starts without the
> variable and every Android call fails with `jar_configured: false` /
> `failure_kind: "jar"`. There is no warning.

> ⚠️ The MCP server process is spawned at OpenCode **startup**. After editing the
> config, restart or reconnect the client — an already-running REA process keeps
> its old environment.

### A.4 Verify without restarting

The CLI exercises the same provider, so it can validate the setup immediately:

```bash
# PowerShell
$env:REA_JADX_MCP_JAR = "C:\Users\Henry\.local\share\rea\android\jadx-headless-mcp-0.7.1-all.jar"
$env:JAVA_HOME        = "C:\Program Files\Java\jdk-25.0.4.1"
npx -y rea-agents@6.7.0 inspect-android-package "<apk>" --format json `
  --filter-output normalized_result.package_name,provider.id,provider.version
```

Expected on success:

```json
{"normalized_result":{"package_name":"com.alexter.dota2helper","class_count":20568,
 "resource_count":2437},"provider":{"id":"jadx","version":"0.7.1"}}
```

If it returns `capability_unavailable` / `unsupported_provider` with
`failure_code: "not_configured"`, the variable still is not reaching the
process — check the key name (`environment`), the JAR path's existence, and
that `JAVA_HOME` points at a full JDK rather than a JRE.

### A.5 Provider notes

- One worker, provider deadlines; the APK is **never launched** and no emulator
  is required.
- Manifest entries and decompiled text are **static observations**, not
  execution or policy enforcement.
- Incoming references are recovered static relationships — reflection, dynamic
  loading, and unresolved calls remain unknown.
- Preserve artifact digests, locations, diagnostics, and incomplete coverage.
