# LeadFlow AI · release-build ProGuard rules
# Keeps just enough symbol info to keep the deps that use reflection or
# native/JNI happy under R8 shrinking.

# --- Flutter engine (already kept by the default plugin, but explicit here) ---
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Google ML Kit (text recognition uses dynamic classloading) ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.mlkit.**

# --- ExoPlayer (used by just_audio) ---
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# --- OkHttp / http (used by Supabase + our Groq/Gemini/OCR.space calls) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# --- Kotlin coroutines internal reflection ---
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# --- SharedPreferences (from shared_preferences plugin) — nothing needed;
#     default rules handle it. Explicit dontwarn for JDK apis. ---
-dontwarn javax.annotation.**
-dontwarn java.lang.invoke.StringConcatFactory
