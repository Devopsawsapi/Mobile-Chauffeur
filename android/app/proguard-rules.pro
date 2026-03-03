# ── SLF4J (Pusher) ──
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# ── Pusher ──
-dontwarn com.pusher.**
-keep class com.pusher.** { *; }

# ── OkHttp ──
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# ── Gson ──
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }

# ── Flutter Local Notifications ──
-dontwarn com.dexterous.**
-keep class com.dexterous.** { *; }