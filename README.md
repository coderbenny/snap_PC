# Snapit Desktop

![Platform macOS](https://img.shields.io/badge/platform-macOS%2010.14%2B-lightgrey?logo=apple)
![Platform Windows](https://img.shields.io/badge/platform-Windows%2010%2B-blue?logo=windows)
![Flutter](https://img.shields.io/badge/Flutter-3.44%2B-02569B?logo=flutter)
![Dart SDK](https://img.shields.io/badge/Dart-%5E3.12.1-0175C2?logo=dart)
![License](https://img.shields.io/badge/license-MIT-green)

**Snapit** is a universal clipboard vault for macOS and Windows. Every item you copy is captured automatically, encrypted locally with AES-256-GCM, and synced end-to-end encrypted to the Snapit backend so your clipboard history is available on every device you own.

---

## Features

- **Automatic capture** — watches the system clipboard in the background; every copied text, URL, or image is stored instantly.
- **AES-256-GCM encryption** — all items are encrypted at rest before touching the local database. Keys are derived with PBKDF2-SHA256 at 600 000 iterations and stored in the OS keychain (macOS Keychain / Windows DPAPI).
- **Full-text search (FTS5)** — find any clipping by keyword in milliseconds via SQLite FTS5.
- **Cross-device sync** — end-to-end encrypted sync over HTTPS with the Snapit backend. Real-time plan-change events arrive via Server-Sent Events.
- **Quick-access overlay** — a global hotkey (default `⌘ Shift V` / `Ctrl Shift V`) opens a compact picker window without leaving your current app.
- **System tray integration** — Snapit lives in the menu bar / notification area. Click the icon to open the main vault, right-click for options.
- **Device registration & heartbeat** — devices are registered and kept alive so the server knows which devices are active.
- **Offline-first** — the full local database is always available; sync runs on a 30-second timer and retries automatically when connectivity returns.

---

## System Requirements

| | macOS | Windows |
|---|---|---|
| OS version | macOS 10.14 Mojave or later | Windows 10 (build 1903) or later |
| Flutter SDK | 3.44 or later | 3.44 or later |
| Toolchain | Xcode 15+ with Command Line Tools | Visual Studio 2022 with "Desktop development with C++" workload |
| Architecture | arm64 (Apple Silicon) or x86_64 | x86_64 |

---

## Installation

### Homebrew (recommended for macOS)

```bash
brew tap coderbenny/tap
brew install --cask snapit
brew trust --cask coderbenny/tap/snapit
```

That's it — Snapit will appear in your Applications folder and the menu bar icon will be ready to use.

> The `brew trust` step removes the macOS quarantine flag so the app opens without a security warning. Snapit is ad-hoc signed; this is expected behaviour for apps distributed outside the Mac App Store.

### Download the DMG directly

Grab the latest `.dmg` from the [Releases page](https://github.com/coderbenny/snap_PC/releases), open it, drag Snapit to Applications, then run:

```bash
xattr -dr com.apple.quarantine /Applications/Snapit.app
```

---

## Build from Source

### 1. Clone the repository

```bash
git clone https://github.com/coderbenny/snap_PC
cd snap_PC
```

### 2. Install Flutter dependencies

```bash
cd snap_PC
flutter pub get
```

### 3. Generate Riverpod code

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Configure the backend URL

Copy the environment template and set the API base URL to wherever the Snapit server is running (see [Backend Configuration](#backend-configuration)):

```bash
# The app reads Snapit_API_URL from app_constants.dart; edit that file or
# set the value before building.
```

### 5. Run on macOS

```bash
flutter run -d macos
```

### 6. Run on Windows

```bash
flutter run -d windows
```

### Building release binaries

```bash
# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

---

## Backend Configuration

The desktop app connects to the Snapit backend defined in:

```
lib/core/constants/app_constants.dart
```

Set the `apiBaseUrl` constant to the address of the running server. For local development, start the server first:

```bash
cd ../server
# follow the server README to start the backend
```

The default development URL is `http://localhost:5559/snap`. For production, the app automatically uses `https://api.snapit.ink/snap`.

---

## Keyboard Shortcuts

| Action | macOS | Windows |
|---|---|---|
| Open Quick Picker | `⌘ Shift V` | `Ctrl Shift V` |
| Open Main Vault | Click tray icon | Click tray icon |
| Search clipboard history | Type in Quick Picker | Type in Quick Picker |
| Paste selected item | `Return` | `Enter` |
| Close overlay | `Esc` | `Esc` |
| Settings | `⌘ ,` | `Ctrl ,` |
| Quit Snapit | Right-click tray → Quit | Right-click tray → Quit |

---

## Project Structure

```
pc/
├── lib/
│   ├── main.dart                   # App entry point, tray + window init
│   ├── app.dart                    # Root MaterialApp + Riverpod ProviderScope
│   ├── router.dart                 # go_router route definitions
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart  # API URL, timeouts, encryption params
│   │   ├── models/
│   │   │   └── clip_item.dart      # ClipItem domain model
│   │   ├── providers.dart          # Top-level Riverpod providers
│   │   └── services/
│   │       ├── api_client.dart         # Dio HTTP client + auth interceptor
│   │       ├── clipboard_service.dart  # clipboard_watcher integration
│   │       ├── database_service.dart   # sqflite_common_ffi + FTS5 setup
│   │       ├── device_registration_service.dart
│   │       ├── encryption_service.dart # AES-256-GCM + PBKDF2, runs in Isolate
│   │       ├── event_stream_service.dart # SSE client for real-time events
│   │       ├── secure_storage_service.dart # flutter_secure_storage wrapper
│   │       ├── sync_service.dart       # 30 s timer sync orchestrator
│   │       └── tray_service.dart       # tray_manager integration
│   ├── features/
│   │   ├── auth/                   # Sign-in / sign-up screens
│   │   ├── clipboard/              # Main vault list + detail views
│   │   ├── quick/                  # Quick-access overlay window
│   │   └── settings/               # Settings screen
│   └── shared/
│       ├── theme/                  # AppTheme (light + dark)
│       └── widgets/                # Shared UI components
├── assets/
│   └── icons/                      # Tray icons (macOS template + Windows ICO)
├── macos/                          # macOS runner + entitlements
├── windows/                        # Windows runner + resource files
├── pubspec.yaml
└── analysis_options.yaml
```

---

## Related Repositories

Snapit is split across separate repositories:

| Repo | Description |
|---|---|
| [snap_PC](https://github.com/coderbenny/snap_PC) | **This repo** — Flutter desktop app (macOS) |
| [snap_mobile](https://github.com/coderbenny/snap_mobile) | Flutter Android app |
| [snap_BE](https://github.com/coderbenny/snap_BE) | Flask REST API, SSE event stream, WebSocket file-transfer relay |
| [snap_FE](https://github.com/coderbenny/snap_FE) | Next.js web dashboard and marketing site |

All clients share the same end-to-end encryption scheme. The server never sees plaintext clipboard data.

---

## License

MIT — see [LICENSE](LICENSE).
