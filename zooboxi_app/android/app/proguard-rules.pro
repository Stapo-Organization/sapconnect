# Flutter's own embedding rules are added by the Flutter Gradle plugin.

# flutter_local_notifications serialises scheduled notifications with Gson
# (rules from google/gson's android-proguard-example).
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep class com.dexterous.** { *; }

# flutter_secure_storage persists cipher enums by name() and parses them back
# with valueOf(); renamed constants would look like an algorithm change and
# force a key migration on every launch.
-keepclassmembers enum * {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Deferred components are not used; Flutter references Play Core anyway.
-dontwarn com.google.android.play.core.**

# Kotlin coroutines / OkHttp (transitive via Firebase, MyFatoorah)
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# MyFatoorah — replaces the plugin's consumer file (see build.gradle.kts).
-keep class com.myfatoorah.** { *; }
-keep class com.myfatoorahflutter.** { *; }
-keep class org.xmlpull.** { *; }
-keepclassmembers class org.xmlpull.** { *; }
-dontwarn org.slf4j.impl.**
-dontwarn java.lang.invoke.StringConcatFactory
-dontwarn android.content.res.**
