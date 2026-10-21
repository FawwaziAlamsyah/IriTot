# Flutter SharedPreferences and JNI Keep Rules
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
-dontwarn com.github.dart_lang.jni.**
