---
description: Launch the Flutter customer app on Pixel 9 Pro emulator
---

// turbo-all

1. Launch the Pixel 9 Pro emulator:
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter && flutter emulators --launch Pixel_9_Pro_API_35
```

2. Wait for the emulator to boot and be detected by ADB (poll until `emulator-5554` appears):
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter && sleep 10 && adb wait-for-device
```

3. Run the customer app on the emulator:
```bash
cd /Users/apple/Desktop/gutzo/flutter/GutzoFlutter/apps/customer_app && flutter run -d emulator-5554
```
