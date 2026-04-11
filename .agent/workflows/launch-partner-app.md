---
description: Launch the Flutter partner app on the active emulator
---

// turbo-all

1. Ensure the emulator is running (or launch it if not):
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter && (flutter devices | grep -q "emulator-5554" || flutter emulators --launch Pixel_9_Pro_API_35)
```

2. Wait for the emulator to boot and be detected by ADB:
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter && adb wait-for-device
```

3. Run the partner app on the emulator:
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter/apps/partner_app && flutter run -d emulator-5554
```
