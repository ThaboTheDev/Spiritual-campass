# TSHK Compass — R8 keep rules.
# Flutter's own rules are added by the Flutter Gradle plugin; these cover the
# plugins that use reflection or Play Core stubs.

# Flutter embedding / plugins.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Deferred components / Play Core are not used; silence the references.
-dontwarn com.google.android.play.core.**

# flutter_secure_storage (Tink / keystore).
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# Geolocator (Google Play services location is optional).
-dontwarn com.google.android.gms.**

# Keep annotations and generic signatures for JSON-free but reflective code.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
