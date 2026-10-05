# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Prevent R8 from stripping native plugin calls
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends io.flutter.plugin.common.PluginRegistry
-keep public class * extends io.flutter.embedding.engine.plugins.FlutterPlugin

# Camera plugin
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# Supabase / WebSockets
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase
