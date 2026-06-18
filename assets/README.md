# Font Assets — Inter Typeface

This app uses the **Inter** font family from Google Fonts.

## How to set up the fonts

1. Download the Inter font files from [Google Fonts — Inter](https://fonts.google.com/specimen/Inter).
2. Place the following TTF files in this `assets/fonts/` directory:

   ```
   assets/fonts/
   ├── Inter-Regular.ttf
   ├── Inter-Medium.ttf
   ├── Inter-SemiBold.ttf
   ├── Inter-Bold.ttf
   └── Inter-Light.ttf       (optional)
   ```

3. Verify that `pubspec.yaml` contains the font declaration under `flutter:`:

   ```yaml
   flutter:
     fonts:
       - family: Inter
         fonts:
           - asset: assets/fonts/Inter-Regular.ttf
           - asset: assets/fonts/Inter-Medium.ttf
             weight: 500
           - asset: assets/fonts/Inter-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Inter-Bold.ttf
             weight: 700
           - asset: assets/fonts/Inter-Light.ttf
             weight: 300
   ```

> **Note:** Without these font files the app will fall back to the platform
> default (Roboto on Android, San Francisco on iOS/macOS). It will still
> compile and run, but the intended typography will not be applied.