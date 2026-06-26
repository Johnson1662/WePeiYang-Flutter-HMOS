# Repository Guidelines

## Project Overview

WePeiYang-Flutter is the Flutter-based mobile client for 微北洋 (WePeiYang), the official campus app of Tianjin University (TJU). It provides features including course scheduling, GPA tracking, campus forum (feedback/QA/lost-and-found), study room finder, AI chatbot (小天), and account management.

The project targets Android, iOS, Windows, and HarmonyOS NEXT (OHOS) platforms. OHOS support uses a custom Flutter SDK fork (`oh-3.41.9-dev`) with `devecocli` as the build tool.

---

## Architecture & Data Flow

```
lib/main.dart
  └─ runZonedGuarded → WidgetsFlutterBinding
    └─ Init chain: EnvConfig → StorageUtil → CommonPreferences → NetStatusListener
      └─ MultiProvider (all module providers)
        └─ WpyTheme (InheritedWidget)
          └─ MaterialApp (RouterManager.onGenerateRoute)
```

**Data flow:** UI → Provider/ChangeNotifier → DioAbstract service → API → Response → Notifier notify → UI rebuild

Each feature module follows a consistent structure:
- `model/` — ChangeNotifier(s) + provider list
- `view/` — Pages and widgets
- `network/` — DioAbstract subclass for API calls
- `XxxRouter` — Static route definitions

---

## Key Directories

| Path | Purpose |
|------|---------|
| `lib/` | Main Flutter source code |
| `lib/commons/` | Shared infrastructure (network, theme, widgets, preferences, channels) |
| `lib/commons/network/` | Dio networking (`wpy_dio.dart`, `dio_abstract.dart`, interceptors) |
| `lib/commons/themes/` | Theme system (`WpyTheme`, 8 color schemes in `scheme/`) |
| `lib/commons/widgets/` | Reusable widgets (`wpy_pic.dart`, `loading.dart`, `SpoilerMask.dart`) |
| `lib/commons/preferences/` | `CommonPreferences` — SharedPreferences typed wrapper |
| `lib/commons/channel/` | OHOS MethodChannel bridges (push, save, settings, download) |
| `lib/feedback/` | Campus forum/QA module |
| `lib/schedule/` | Course schedule module |
| `lib/gpa/` | Grade tracking module |
| `lib/auth/` | Login/register/profile/settings |
| `lib/studyroom/` | Study room finder |
| `lib/lost_and_found/` | Lost & found board |
| `lib/home/` | Dashboard with tool cards |
| `lib/xiaotian/` | AI chatbot ("小天") |
| `lib/message/` | Notifications/messages |
| `lib/account/` | Account settings |
| `test/` | Test files (minimal) |
| `assets/` | Fonts, PNGs, SVGs organized by module |
| `android/` | Android native (Gradle, Kotlin, push configs) |
| `harmonyos/` | OHOS native (hvigor, entry, wepei_module Flutter module) |
| `harmonyos/wepei_module/` | Flutter module for OHOS (`.ohos/` is the build dir) |
| `harmonyos/entry/` | OHOS entry ability + pages + plugins |
| `scripts/` | PowerShell build/release scripts |

---

## Development Commands

### Flutter (Android/iOS)

```bash
flutter run --dart-define=ENVIRONMENT=DEVELOP
flutter build apk --dart-define=ENVIRONMENT=RELEASE --split-per-abi
```

### OHOS (HarmonyOS NEXT)

```bash
# Build + install + launch (debug)
cd harmonyos\wepei_module\.ohos
$env:PUB_CACHE = "D:\pub-cache"
devecocli run

# Release build
devecocli build --build-mode release
devecocli run --skip-build

# Skip build, just deploy existing HAP
devecocli run --skip-build

# Full build only
devecocli build

# HAR build (Flutter module)
cd harmonyos\wepei_module
flutter build har --debug
```

### Tests

```bash
flutter test                          # Run all Flutter tests
flutter test test/widget_test.dart    # Single test file
```

### Scripts

```bash
powershell -File scripts/new-apk.ps1          # Build release APK
powershell -File scripts/package.ps1           # Full release pipeline
powershell -File scripts/hotfix_package.ps1   # Build hotfix ZIP
powershell -File scripts/test.ps1              # Sync version strings
```

---

## Code Conventions & Common Patterns

### State Management: Provider + ChangeNotifier

Each module exports a list of `SingleChildWidget` providers, merged at the root `MultiProvider` in `main.dart`:

```dart
// lib/feedback/model/feedback_providers.dart
List<SingleChildWidget> feedbackProviders = [
  ChangeNotifierProvider(create: (_) => FeedbackNotifier()),
  ChangeNotifierProvider(create: (_) => PostDetailNotifier()),
];
```

```dart
// lib/main.dart
MultiProvider(
  providers: [
    ...authProviders,
    ...feedbackProviders,
    ...scheduleProviders,
    ...gpaProviders,
    ...studyroomProviders,
    ...lafProviders,
  ],
)
```

### Networking: DioAbstract pattern

Every API module extends `DioAbstract` with its own base URL and interceptors:

```dart
class FeedbackService extends DioAbstract {
  @override String baseUrl = EnvConfig.QNHD + '/feedback';
  @override List<Interceptor> interceptors = [AuthInterceptor(), NetCheckInterceptor()];
  Future<List<Post>> getPosts() async {
    final res = await get('/list', queryParams: {...});
    return (res.data as List).map((e) => Post.fromJson(e)).toList();
  }
}
```

Features: automatic retry (3 attempts on `SocketException`/`TimeoutException`), SSL bypass option for OHOS, `AsyncTimer` mixin for debounced requests.

### Routing: Static module routers

```dart
// lib/feedback/feedback_router.dart
class FeedbackRouter {
  static const String postDetail = '/feedback/post';

  static final Map<String, Widget Function(dynamic)> routers = {
    postDetail: (args) => PostDetailPage(postId: args as int),
  };
}

// lib/commons/util/router_manager.dart
class RouterManager {
  static Route<dynamic> create(RouteSettings settings) {
    final allRoutes = {
      ...AuthRouter.routers, ...FeedbackRouter.routers, ...HomeRouter.routers,
      ...ScheduleRouter.routers, ...GPARouter.routers, ...StudyRoomRouter.routers,
      ...MessageRouter.routers, ...LAFRouter.routers,
    };
    final builder = allRoutes[settings.name];
    if (builder != null) return MaterialPageRoute(builder: (_) => builder(settings.arguments));
    return MaterialPageRoute(builder: (_) => const NotFoundPage());
  }
}
```

### Error handling

- **Network errors:** `ErrorInterceptor` wraps `DioException` into Chinese messages (`DioExceptionType.connectionTimeout` → "网络连接超时")
- **Custom exception:** `WpyDioException` (subclass of `DioException`)
- **Global handler:** `runZonedGuarded` in `main.dart` captures unhandled errors via `Logger.reportError()`
- **Feature-level:** Standard try-catch in service methods, error states in ChangeNotifiers
- **Platform:** OHOS MethodChannel calls wrapped in `.catchError()` (e.g., `push_manager.dart`)

### Image Loading

Unified `WpyPic` widget (`lib/commons/widgets/wpy_pic.dart`):
- Asset images: `Image.asset`
- SVG images: `flutter_svg`'s `SvgPicture`
- Network images: `CachedNetworkImage` on Android/iOS, custom `_ohosNetwork` on OHOS (raw HttpClient with SSL bypass + in-memory `static Map<String, Uint8List>` cache)
- Disk cache: `ImageCacheService` singleton with HTTP cache-control header parsing

### Theme System

Custom `WpyTheme` (InheritedWidget) with 8 color schemes defined in `lib/commons/themes/scheme/`:
- Red, Yellow, Purple, Orange, Green, Light (white), Haitang (pink), Violet
- Each scheme maps ~100 `WpyColorKey` entries with either color values or `ColorMapper` functions (hue-shift from a base color)
- Dark mode: auto-follows system via `MediaQuery.platformBrightness`, iOS uses native `MethodChannel` for `reduceTransparency`

---

## Important Files

| File | Role |
|------|------|
| `lib/main.dart` | App entry point, init chain, MultiProvider, router setup |
| `lib/commons/network/wpy_dio.dart` | Network library barrel file |
| `lib/commons/network/dio_abstract.dart` | `DioAbstract` base class for all API services |
| `lib/commons/network/error_interceptor.dart` | `ErrorInterceptor` + `WpyDioException` |
| `lib/commons/util/router_manager.dart` | Centralized route generation |
| `lib/commons/themes/wpy_theme.dart` | `WpyTheme` InheritedWidget |
| `lib/commons/preferences/common_prefs.dart` | SharedPreferences typed wrapper |
| `lib/commons/widgets/wpy_pic.dart` | Unified image widget (asset/svg/network, OHOS fallback) |
| `lib/commons/channel/image_save/image_save.dart` | OHOS MethodChannel bridge (save/pick images) |
| `lib/commons/environment/config.dart` | `EnvConfig` — base URLs per environment |
| `harmonyos/wepei_module/pubspec.yaml` | OHOS Flutter module dependencies |
| `harmonyos/wepei_module/.ohos/build-profile.json5` | OHOS signing config |
| `harmonyos/entry/src/main/ets/entryability/EntryAbility.ets` | OHOS EntryAbility + SaveImgHandler |
| `pubspec.yaml` | Root project dependencies |

---

## Runtime/Tooling Preferences

- **Flutter SDK:** Custom fork at `D:\Development\flutter_flutter` (OHOS branch: `oh-3.41.9-dev`)
- **Dart SDK:** ^3.0.0 (root), ^3.6.2 (OHOS module)
- **Package manager:** `dart pub` / `flutter pub get`; `PUB_CACHE` set to `D:\pub-cache` for OHOS builds
- **OHOS build tool:** `devecocli` (wraps hvigor + ohpm + hdc); run from `.ohos/` directory
- **OHPM:** Uses `D:\DevEco Studio\tools\ohpm\bin\pm-cli.js`; registry `ohpm.openharmony.cn`
- **Device connection:** hdc wireless at `192.168.137.159:46715`
- **Proxy:** `.bash_profile` sets `HTTP_PROXY=127.0.0.1:7890` and `HTTPS_PROXY=127.0.0.1:7890`
- **Node.js:** `D:\DevEco Studio\tools\node\node.exe` (used by hvigor/ohpm)
- **Java:** JDK 21.0.10 at `D:\Program Files\Java\jdk-21.0.10`
- **Hvigor daemon:** Ports 45000-45099; currently disabled due to TIME_WAIT saturation, falls back to no-daemon mode

---

## Testing & QA

- **Flutter tests:** Minimal — only the default `flutter_test` counter smoke test at `test/widget_test.dart`
- **No mocking/coverage:** No mockito, no golden tests, no coverage tooling
- **OHOS tests:** Hypium framework:
  - Unit: `harmonyos/entry/src/test/LocalUnit.test.ets`
  - Instrument: `harmonyos/entry/src/ohosTest/ets/test/Ability.test.ets`
- **Linting:** `flutter_lints` default rules via `analysis_options.yaml`
- **QA pattern:** Manual testing on device; no CI pipeline (no GitHub Actions, etc.)
- **Build verification:** `flutter analyze` and `flutter test` before release; OHOS builds verified by `devecocli build` exit code
