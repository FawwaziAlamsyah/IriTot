# Flutter SharedPreferences dan JNI
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**
-dontwarn com.github.dart_lang.jni.**

# Kelas Kotlin yang dicari lewat JNI berdasarkan nama (cegah R8 me-rename)
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
