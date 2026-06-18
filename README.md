# API Tester - Flutter

A professional, feature-rich API testing application built with Flutter. Test REST APIs, manage collections, run automated tests, and analyze responses — all from your mobile device.

## Features

### Request Builder
- Full HTTP client supporting GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS
- Dynamic header and query parameter editors
- Body editor with support for: JSON, XML, HTML, form-data (with file upload), x-www-form-urlencoded, binary
- Real-time JSON/XML syntax highlighting and validation
- Environment variable substitution (`{{variable}}`)
- Proxy configuration per request (HTTP/SOCKS5)
- Configurable timeout, SSL verification, and redirect following

### Response Viewer
- Status code with color-coded badges
- Response time and size display
- JSON/XML/HTML syntax highlighting with line numbers
- Collapsible JSON tree view
- Search within response body
- Copy and share responses

### Collection Runner & Testing
- Organize requests into collections
- Run collections sequentially with configurable delays
- Assertion engine: status code, body contains, header exists, response time
- Detailed test reports with pass/fail summary
- Stop-on-error configuration

### Import & Export
- **OpenAPI 3.0 / Swagger 2.0** — Import full API specs (JSON/YAML)
- **Postman Collection v2.1** — Import from Postman exports
- **HAR Files** — Import HTTP Archive files
- **cURL** — Paste a cURL command and parse it into a request
- **HTML Scraper** — Extract API endpoints from documentation pages

### Deep Response Analyzer
- JSON/XML structure validation with error positioning
- JSON Path / XPath evaluator
- Diff tool to compare two responses
- Auto-generate JSON Schema from responses
- JWT decoder with expiration status

### Extra Tools
- **Code Generator** — Generate code snippets in Dart, Python, JavaScript, Java, cURL, C#, Go
- **WebSocket Client** — Connect to ws:// and wss:// endpoints, send/receive messages
- **GraphQL Explorer** — Query editor with introspection support

### Environment & Variables
- Multiple named environments (Development, Staging, Production)
- Global variables shared across workspaces
- Variable types: string, number, boolean
- Extract values from responses using JSON path

### Floating Window
- Overlay bubble for quick API testing from any screen
- Compact request panel with method, URL, send, and response preview
- Requires "draw over apps" permission on Android

### UI/UX
- Material Design 3 with dynamic color theming
- Dark/Light/System theme modes
- Responsive layout (phone + tablet with NavigationRail)
- Inter font for clean readability
- Smooth animations and transitions

## Architecture

Clean Architecture with three layers:

```
lib/
├── core/           # Constants, DI, theme, utils, extensions
├── data/           # Drift database, repositories impl, mappers, API service
├── domain/         # Entities, repository interfaces, use cases
├── presentation/   # Providers (Riverpod), screens, widgets, routes
└── main.dart
```

- **State Management**: Riverpod
- **Dependency Injection**: GetIt
- **HTTP Client**: Dio
- **Local Database**: Drift (SQLite)
- **Routing**: GoRouter

## Getting Started

### Prerequisites
- Flutter 3.16+ (stable channel)
- Dart 3.2+
- Android Studio / Xcode for platform builds
- Minimum SDK: Android 21 (API 21), iOS 14

### Setup

1. **Clone the repository** and navigate to the project:
   ```bash
   cd api_tester
   ```

2. **Install fonts** — Download the Inter font family from [Google Fonts](https://fonts.google.com/specimen/Inter) and place the TTF files in `assets/fonts/`:
   - `Inter-Regular.ttf`
   - `Inter-Medium.ttf`
   - `Inter-SemiBold.ttf`
   - `Inter-Bold.ttf`

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Generate code** (freezed, json_serializable, drift, riverpod):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

5. **Run the app**:
   ```bash
   flutter run
   ```

### Build for Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

## Running Tests

```bash
# Run all tests
flutter test

# Run unit tests only
flutter test test/unit/

# Run widget tests only
flutter test test/widget/

# Run integration tests (requires device/emulator)
flutter test integration_test/

# Static analysis
flutter analyze
```

## Project Structure

```
api_tester/
├── android/              # Android platform configuration
├── ios/                  # iOS platform configuration
├── assets/
│   ├── fonts/            # Inter font files (user must provide)
│   └── lottie/           # Lottie animations
├── lib/
│   ├── core/
│   │   ├── constants/    # App-wide constants, API defaults
│   │   ├── di/           # GetIt dependency injection setup
│   │   ├── errors/       # Exceptions and failures
│   │   ├── services/     # Floating window, HAR parser, HTML scraper
│   │   ├── theme/        # Material 3 theme configuration
│   │   ├── utils/        # Dio interceptors, helpers, parsers
│   │   └── extensions/   # String, Context, DioResponse extensions
│   ├── data/
│   │   ├── datasources/  # Local (Drift DB) and remote (Dio API service)
│   │   ├── mappers/      # Entity <-> DB model converters
│   │   └── repositories/ # Repository implementations
│   ├── domain/
│   │   ├── entities/     # Freezed data classes
│   │   ├── repositories/ # Abstract repository interfaces
│   │   ├── usecases/     # Business logic (workspace, request, collection, import, tools)
│   │   └── exceptions/   # Domain-specific exceptions
│   ├── presentation/
│   │   ├── providers/    # Riverpod state management
│   │   ├── routes/       # GoRouter configuration
│   │   ├── screens/      # All application screens
│   │   └── widgets/      # Reusable UI components
│   └── main.dart
├── test/
│   ├── unit/             # Unit tests (utils, use cases, services)
│   ├── widget/           # Widget tests
│   └── integration/      # End-to-end integration tests
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

## Technologies

| Category | Technology |
|----------|-----------|
| Framework | Flutter 3.16+, Dart 3.2+ |
| State Management | Riverpod 2.x |
| HTTP Client | Dio 5.x |
| Database | Drift (SQLite) |
| DI | GetIt |
| Routing | GoRouter |
| Icons | Material Symbols Icons |
| Font | Google Fonts Inter |
| Animations | flutter_animate, Lottie |
| Code Highlighting | flutter_highlight |

## License

Private project. All rights reserved.