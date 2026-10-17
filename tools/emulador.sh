#!/bin/bash
# Abre o Noto num Android virtual, tira prints e guarda o log de erros.
set -x
OUT=diagnostico
mkdir -p $OUT
APK=$(ls apk/app-x86_64-release.apk)
PKG=com.example.bloco_personalizavel
adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb install -r -g "$APK"
adb logcat -c

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }

adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 20
shot 1-primeira-abertura
# Pula o tutorial: toca em "Pular" (canto superior direito)
W=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f2)
adb shell input tap $((W*88/100)) $((H*7/100))
sleep 6
shot 2-depois-de-pular
# Toca no + e cria uma nota
adb shell input tap $((W*88/100)) $((H*90/100))
sleep 4
shot 3-menu-criar
adb shell input keyevent KEYCODE_BACK
sleep 2
# Fecha e abre de novo (como depois de atualizar)
adb shell am force-stop $PKG
sleep 2
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 20
shot 4-segunda-abertura
adb shell am force-stop $PKG
sleep 2
adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1
sleep 30
shot 5-terceira-abertura

adb logcat -d > "$OUT/logcat-completo.txt"
grep -E "flutter|AndroidRuntime|FATAL|Exception|$PKG" "$OUT/logcat-completo.txt" | grep -v "^$" > "$OUT/logcat-noto.txt" || true
tail -c 900000 "$OUT/logcat-completo.txt" > "$OUT/logcat-fim.txt"
ls -la $OUT
true
