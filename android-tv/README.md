# EZ-AZ TV — Android TV Wrapper

A minimal single-Activity Kotlin app that wraps `https://ez-az.net/tv` in a
fullscreen WebView. This is the app families install on their Android TV /
Google TV / Fire TV box to play EZ-AZ games together on the big screen.

The whole app is intentionally tiny — no networking layer, no analytics, no
in-app navigation. The TV does one thing: load the TV-optimised page from the
web app and let the user drive it with their remote.

## What's in here

```
android-tv/
├── app/
│   ├── build.gradle.kts              app module config (Kotlin DSL)
│   ├── proguard-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml       Leanback launcher + permissions
│       ├── java/net/ezaz/tv/
│       │   ├── EzAzApplication.kt    enables WebView debugging in debug builds
│       │   └── MainActivity.kt       fullscreen WebView, error screen, immersive mode
│       └── res/
│           ├── drawable/
│           │   ├── banner.xml        Leanback banner (320x180 vector)
│           │   └── ic_launcher_foreground.xml
│           ├── mipmap-anydpi-v26/
│           │   ├── ic_launcher.xml         adaptive launcher icon
│           │   └── ic_launcher_round.xml
│           └── values/
│               ├── colors.xml        EZ-AZ palette
│               ├── strings.xml       app name + offline copy
│               ├── themes.xml        fullscreen NoActionBar theme
│               └── ic_launcher_background.xml
├── build.gradle.kts                  top-level plugin pinning
├── settings.gradle.kts
├── gradle.properties
├── gradle/wrapper/gradle-wrapper.properties   Gradle 8.9
├── gradlew, gradlew.bat              wrapper scripts
└── .gitignore                        Android build artifacts
```

## Requirements

| Tool              | Version                |
|-------------------|------------------------|
| JDK               | 17                     |
| Android SDK       | API 34 (build target)  |
| Min device API    | 26 (Android 8.0 Oreo)  |
| Gradle (via wrapper) | 8.9                 |
| Android Gradle Plugin | 8.5.0              |
| Kotlin            | 1.9.24                 |

`minSdk = 26` covers virtually every Android TV device sold in the last
several years and lets us use adaptive launcher icons natively (no PNG
fallbacks for older platform versions).

## First-time setup

The Gradle wrapper jar is **not committed**. Generate it once after cloning:

```sh
cd android-tv
gradle wrapper --gradle-version 8.9
```

If you don't have a system Gradle install, opening this folder in Android
Studio will populate the wrapper for you.

You also need a `local.properties` pointing to your Android SDK
(Android Studio writes this for you):

```properties
sdk.dir=/Users/you/Library/Android/sdk
```

## Build

```sh
# Debug build (installs and runs on a connected device or emulator)
./gradlew :app:installDebug

# Release APK
./gradlew :app:assembleRelease

# Release AAB (what you upload to Google Play)
./gradlew :app:bundleRelease
```

Outputs land in `app/build/outputs/apk/release/` and `app/build/outputs/bundle/release/`.

## Test on an emulator

In Android Studio, create an Android TV emulator:

1. *Tools → Device Manager → Create Device*
2. Category: **TV** → pick *Android TV (1080p)*
3. System Image: API 34 (or any API ≥ 26 with the *Google TV* image)
4. Run the app — it should boot straight into the EZ-AZ TV page

To prove the D-pad works, use the emulator's directional pad (or the
keyboard's arrow keys + Enter).

## Test on a real device

```sh
# Enable Developer Options on the TV (Settings → About → click "Build" 7 times)
# Enable USB debugging or Network debugging
adb connect <tv-ip>:5555
adb install app/build/outputs/apk/debug/app-debug.apk
```

For Chromecast with Google TV, Fire TV, Sony BRAVIA, etc., the install flow
is the same.

## Architecture notes

### Why a WebView instead of native?

All UI lives in the web app (`app/views/tv/show.html.erb` in the Rails repo).
Keeping the TV experience as a web page means:

- A single source of truth — when we ship a new game shelf or fix a layout
  bug, the TV picks it up next reload (no Play Store roundtrip)
- The same page can be tested in any browser
- The eventual ActionCable / WebSocket integration (issue #3) just works
  inside the WebView with no extra plumbing

### Manifest details

```xml
<uses-feature android:name="android.software.leanback" android:required="true" />
<uses-feature android:name="android.hardware.touchscreen" android:required="false" />
```

These two declarations are what mark the app as a TV app. Together they:

- Make the app appear in the Android TV / Google TV launcher (Leanback)
- Tell the Play Store that the app does **not** need a touchscreen — required
  to be eligible for the Android TV form factor on Play Console

The `LEANBACK_LAUNCHER` intent-filter category puts the icon on the TV home
screen. The extra `LAUNCHER` category lets the same APK install on a phone
or tablet too (handy for development, harmless in production).

### MainActivity

`MainActivity.kt` builds its layout in code rather than inflating XML to
keep the APK small. The flow is:

1. Construct a `FrameLayout` with a `WebView` and a hidden error `View` on top
2. Configure the WebView (JavaScript, DOM storage, Web Audio, immersive mode)
3. Check for connectivity and either load `https://ez-az.net/tv` or show
   the offline screen with a *Retry* button
4. Wire the back button to `WebView.canGoBack()` so the remote's BACK key
   navigates within the web app before exiting
5. Forward `MEDIA_PLAY_PAUSE` to `Space` and `MENU` to `Escape` so TV remote
   special keys map to keys the games already understand

The `shouldOverrideUrlLoading` callback keeps the user inside `ez-az.net`;
any external link is dropped rather than handed off to a system browser
(there usually isn't one on a TV anyway).

### Theming

The app theme uses `Theme.EzAzTv.Fullscreen` which strips the action bar
and hides system bars. In `onWindowFocusChanged` we re-enter immersive
mode if the user briefly summons the system UI.

The launcher icon is a vector adaptive icon (Az the dinosaur over the
EZ-AZ background colour), and the Leanback banner is also a vector
(`drawable/banner.xml`) so the asset weight stays minimal.

## Google Play submission checklist

- [ ] Generate a release signing key with `keytool -genkey -v -keystore ezaz-release.keystore -alias ezaz -keyalg RSA -keysize 2048 -validity 10000` (keep this file outside the repo!)
- [ ] Wire the keystore into `app/build.gradle.kts` under `signingConfigs { release { ... } }` (currently the release build is signed with the debug key for development convenience)
- [ ] Bump `versionCode` and `versionName` in `app/build.gradle.kts`
- [ ] Build a signed AAB: `./gradlew :app:bundleRelease`
- [ ] In Play Console, create a new app, choose **Android TV** as the supported device type
- [ ] Upload the AAB
- [ ] Provide:
  - **App icon** (512×512 PNG) — derive from `ic_launcher_foreground.xml` if needed
  - **TV banner** (1280×720) — derive from `banner.xml`
  - **TV screenshots** (at least one 1920×1080 in landscape)
  - Short description, full description, content rating ("Everyone")
  - Privacy policy URL — point to `https://ez-az.net/licence.html` until a
    dedicated privacy policy exists
- [ ] Submit for review

## Open questions / future work

- ActionCable / WebSocket support for room-based multiplayer (#3) does not
  require any Android changes — the WebView already supports both — but
  once we have it, we should test latency on an actual TV to make sure the
  controller→TV path stays under ~50ms
- Consider exporting raster icons (`mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi`)
  if Play Console rejects vector-only adaptive icons in any review
