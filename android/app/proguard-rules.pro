# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep model classes (Freezed/JSON Serializable)
-keep class com.api.tester.domain.entities.** { *; }
-keep class * implements com.api.tester.domain.entities.** { *; }

# Dio
-dontwarn okhttp3.**
-dontwarn okio.**

# Drift
-keep class com.api.tester.data.** { *; }

# Google Fonts
-keep class com.google.fonts.** { *; }