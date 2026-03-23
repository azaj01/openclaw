---
summary: "Running OpenClaw seamlessly within a Flutter Desktop application"
read_when:
  - Building a native Desktop wrapper using Flutter
  - Distributing OpenClaw to non-technical users
title: "Flutter Desktop Integration"
---

# Flutter Desktop Integration

OpenClaw can be packaged into standalone assets and seamlessly spawned from within a Flutter Desktop application. This approach ensures non-technical end users do not need to install Node.js or run any terminal commands — everything runs locally, hidden behind your sleek Flutter UI.

This guide uses the proven packaging mechanism from `openclaw-desktop`, providing two fully self-contained assets that you bundle with your Flutter build:
1. **Portable Node.js** wrapper.
2. **OpenClaw `node_modules` bundle** pre-built for production.

## 1. Generating the Asset Bundles

To generate the distribution bundles on a Windows development machine, run the built-in packaging script from the OpenClaw root directory:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/package-win.ps1
```

The script will:
1. Download a portable release of **Node.js 24**.
2. Download the published **OpenClaw** package directly from the NPM registry.
3. Install production-only dependencies cleanly.
4. Compress everything into two final artifacts ready for Flutter.

### Artifacts generated
Look in `build/flutter-assets/` for the final zip files:
- `node-win-x64.zip` (~34 MB)
- `openclaw.zip` (~70 MB)

*Note: For macOS or Linux targets, you can create a similar script that downloads the appropriate Node.js portable tarballs (e.g. `node-mac-arm64.tar.gz`) alongside the same `openclaw.zip` payload.*

---

## 2. Bundling Assets in Flutter

Copy the generated `.zip` files into your Flutter project's `assets/runtime/` directory:

```text
your_flutter_app/
└── assets/
    └── runtime/
        ├── node-win-x64.zip       ← Portable Node Windows
        └── openclaw.zip           ← OpenClaw production package
```

Update your `pubspec.yaml` to declare the assets and add the `archive` package for extraction:

```yaml
dependencies:
  archive: ^3.4.10

flutter:
  assets:
    - assets/runtime/node-win-x64.zip
    - assets/runtime/openclaw.zip
```

---

## 3. Extracting & Spawning at Runtime

When your Flutter desktop app launches for the first time, it should extract the bundled assets directly to the system's Application Support directory and spawn the OpenClaw gateway via a detached background process.

Here is the robust Dart snippet using `extractFileToDisk` from the `archive` package:

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart'; 

Future<void> extractRuntime() async {
  final appDir = await getApplicationSupportDirectory();
  final runtimeDir = Directory('${appDir.path}/runtime');
  await runtimeDir.create(recursive: true);

  // 1. Extract Portable Node.js
  final nodeAsset = Platform.isWindows
    ? 'assets/runtime/node-win-x64.zip'
    // Fallbacks if you package mac/linux equivalents:
    : Platform.isMacOS 
      ? 'assets/runtime/node-mac-arm64.tar.gz' 
      : 'assets/runtime/node-linux-x64.tar.gz';

  final nodeZipPath = '${runtimeDir.path}/node.zip';
  
  // Only extract if missing (prevents slow startups on subsequent boots)
  if (!await File(nodeZipPath).exists()) {
    print('Extracting Node.js runtime...');
    final nodeData = await rootBundle.load(nodeAsset);
    await File(nodeZipPath).writeAsBytes(nodeData.buffer.asUint8List());
    await extractFileToDisk(nodeZipPath, '${runtimeDir.path}/node/');
  }

  // 2. Extract OpenClaw production package
  final openclawZipPath = '${runtimeDir.path}/openclaw.zip';
  if (!await File(openclawZipPath).exists()) {
    print('Extracting OpenClaw package...');
    final openclawData = await rootBundle.load('assets/runtime/openclaw.zip');
    await File(openclawZipPath).writeAsBytes(openclawData.buffer.asUint8List());
    await extractFileToDisk(openclawZipPath, '${runtimeDir.path}/openclaw/');
  }

  // 3. Resolve binary and entry paths
  final nodeBinPath = Platform.isWindows
    ? '${runtimeDir.path}/node/node-v24.0.0-win-x64/node.exe'
    : '${runtimeDir.path}/node/bin/node';

  // npm pack extracts to a relative 'package' subdirectory inside the zip
  final openclawMjsPath = '${runtimeDir.path}/openclaw/package/openclaw.mjs';

  // 4. Spawn the OpenClaw gateway
  print('Starting OpenClaw gateway background service...');
  final process = await Process.start(
    nodeBinPath,                    
    [
      openclawMjsPath, 
      'gateway', 
      'run', 
      '--bind', 'loopback', 
      '--port', '18789', 
      '--force'
    ],
    mode: ProcessStartMode.detached,
  );
  
  print('OpenClaw gateway spawned with PID: ${process.pid}');
}
```

### Communicating with OpenClaw

Once the process initiates, OpenClaw runs identically to a standard terminal launch. Your Flutter wrapper should establish a connection to `ws://127.0.0.1:18789` using any standard WebSocket client package (e.g. `web_socket_channel`) to exchange messages with your AI agent.
