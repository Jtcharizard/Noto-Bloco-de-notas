# Plugins do Flutter: alguns métodos são chamados direto do código nativo/JNI
# e a otimização do APK achava que ninguém usava.
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.dexterous.** { *; }
-keep class es.antonborri.home_widget.** { *; }
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class kotlin.coroutines.Continuation { *; }
# flutter_local_notifications guarda lembretes com Gson.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature
-keepattributes *Annotation*
