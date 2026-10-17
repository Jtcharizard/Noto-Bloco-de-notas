#!/bin/bash
# Abre o Noto num Android virtual como um usuário faria e falha se o app
# travar, der erro ou não chegar às telas esperadas.
set -x
OUT=diagnostico
mkdir -p $OUT
APK=apk/app-x86_64-release.apk
PKG=com.example.bloco_personalizavel
FAIL=0
adb wait-for-device
adb install -r -g "$APK"
adb logcat -c

shot() { adb exec-out screencap -p > "$OUT/$1.png"; }
screen_text() {
  adb shell uiautomator dump /sdcard/tela.xml >/dev/null 2>&1
  adb shell cat /sdcard/tela.xml 2>/dev/null | grep -o 'text="[^"]*"\|content-desc="[^"]*"' | sed 's/^[^"]*"//; s/"$//' | grep -v '^$'
}
expect_text() {
  # espera até 40 s o texto aparecer
  for i in $(seq 1 20); do
    if screen_text | grep -qi "$1"; then echo "OK: achou '$1'"; return 0; fi
    sleep 2
  done
  echo "::error::Não achou '$1' na tela ($2)"
  screen_text | head -30 | sed 's/^/  tela: /'
  FAIL=1
  return 1
}
launch() { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null; }

W=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f2)

launch
expect_text "Pular" "primeira abertura deveria mostrar o tutorial"
shot 1-primeira-abertura
adb shell input tap $((W*88/100)) $((H*7/100))
expect_text "Criar primeira nota" "depois de pular deveria mostrar a tela inicial"
shot 2-tela-inicial

# Fecha e abre de novo, já com dados salvos (como depois de atualizar).
adb shell am force-stop $PKG
sleep 2
launch
expect_text "Criar primeira nota" "segunda abertura deveria ir direto à tela inicial"
shot 3-segunda-abertura

adb logcat -d > "$OUT/logcat-completo.txt"
grep -E " $PKG|E flutter|AndroidRuntime|FATAL" "$OUT/logcat-completo.txt" > "$OUT/logcat-noto.txt" || true
if grep -qE "E flutter.*Unhandled Exception|FATAL EXCEPTION" "$OUT/logcat-noto.txt"; then
  echo "::error::O app deu erro ao abrir:"
  grep -E "E flutter|FATAL EXCEPTION" "$OUT/logcat-noto.txt" | head -6 | cut -c1-400 | sed 's/^/::error::/'
  FAIL=1
fi
ls -la $OUT
exit $FAIL
