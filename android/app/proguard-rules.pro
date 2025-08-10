# Flutter specific
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Hive
-keep class * extends hive.HiveObject { *; }
-keep class * extends HiveObject { *; }
-keep @hive.HiveType class * { *; }
-keep @HiveType class * { *; }
-keep class **.HiveFieldAdapter { *; }
-keep class *Adapter { *; }

# Keep your model classes
-keep class com.example.productz.** { *; }
-keep class **.models.** { *; }
-keep class **.Product { *; }
-keep class **.ProductAdapter { *; }

# HTTP/Network
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# JSON parsing
-keepattributes Signature
-keepattributes *Annotation*
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }

# Dart/Flutter
-keep class dart.** { *; }
-keep class io.flutter.embedding.** { *; }