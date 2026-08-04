# Supported Platforms

Minimum OS versions required to run Visual Song Book.

| Platform | Minimum Version | Notes |
|---|---|---|
| **Android** | API 21 (Android 5.0 Lollipop) | ARMv7, ARM64, x86 |
| **iOS** | 13.0 | iPhone / iPad |
| **macOS** | 11.0 (Big Sur) | Intel or Apple Silicon |
| **Windows** | Windows 10 (1809+) | x64 |
| **Linux** | Ubuntu 20.04 / GLIBC 2.29 | x64 |

## Feature availability by platform

| Platform | Song CRUD | Projection (secondary window) | MDB Import |
|---|---|---|---|
| Linux | ✅ | ✅ Multi-window | ✅ (mdb-tools) |
| Windows | ✅ | ✅ Multi-window | ⚠️ (requires mdb-tools port) |
| macOS | ✅ | ✅ Multi-window | ✅ (mdb-tools via Homebrew) |
| Android | ✅ | ✅ Fullscreen immersive | ❌ |
| iOS | ✅ | ✅ Fullscreen immersive | ❌ |

## Building

```bash
flutter pub get

# Desktop (Linux)
flutter build linux --release
./scripts/package_appimage.sh          # → build/Visual_Song_Book-*.AppImage

# Android per-ABI
# versionCode comes from --build-number; pass an explicit number so it
# doesn't stay at 1 between releases.
flutter build apk --split-per-abi --release \
  --build-name 1.8.0 --build-number 12

# Run
flutter run -d linux
```
