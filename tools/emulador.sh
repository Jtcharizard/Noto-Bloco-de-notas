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
# Toca no primeiro elemento cujo texto ou descrição contém $1.
tap_text() {
  adb shell uiautomator dump /sdcard/tela.xml >/dev/null 2>&1
  adb shell cat /sdcard/tela.xml > /tmp/tela.xml 2>/dev/null
  local xy
  xy=$(python3 - "$1" <<'PY'
import re, sys, xml.etree.ElementTree as ET
alvo = sys.argv[1].lower()
try:
    root = ET.parse('/tmp/tela.xml').getroot()
except Exception:
    sys.exit(0)
for node in root.iter('node'):
    label = (node.get('text') or '') + ' ' + (node.get('content-desc') or '')
    if alvo in label.lower():
        m = re.findall(r'\d+', node.get('bounds') or '')
        if len(m) == 4:
            x1, y1, x2, y2 = map(int, m)
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)
  if [ -z "$xy" ]; then echo "::warning::Não achei '$1' para tocar"; return 1; fi
  if [ -n "$LONG" ]; then
    adb shell input swipe $xy $xy 900
  else
    adb shell input tap $xy
  fi
  sleep 1.5
}
launch() { adb shell monkey -p $PKG -c android.intent.category.LAUNCHER 1 >/dev/null; }

W=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f1)
H=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1 | cut -dx -f2)

launch
expect_text "Pular" "primeira abertura deveria mostrar o tutorial"
shot 1-primeira-abertura
# Passa por algumas telas do tutorial para conferir as ilustrações.
for n in 2 3 4 5; do
  adb shell input swipe $((W*85/100)) $((H/2)) $((W*15/100)) $((H/2)) 250
  sleep 1.5
  shot 1-tutorial-$n
done
tap_text "Pular" || adb shell input tap $((W*88/100)) $((H*7/100))
expect_text "Criar primeira nota" "depois de pular deveria mostrar a tela inicial"
shot 2-tela-inicial

# Fecha e abre de novo, já com dados salvos (como depois de atualizar).
adb shell am force-stop $PKG
sleep 2
launch
expect_text "Criar primeira nota" "segunda abertura deveria ir direto à tela inicial"
shot 3-segunda-abertura

# Passeio visual: menu da tela inicial, editor, menu da nota e Ajustes.
# Só tira prints; não reprova o build se algum toque não achar o botão.
if tap_text "Menu"; then shot 4-menu-inicial; adb shell input keyevent 4; sleep 1; fi
if tap_text "Criar primeira nota"; then
  sleep 1
  shot 5-criar
  tap_text "Em branco" || true
  sleep 2
  # A nota nova já abre com o teclado no texto.
  adb shell input text "Arroz%sR\$%s25,90"
  adb shell input keyevent 66
  adb shell input text "Carne%sR\$%s48"
  sleep 2
  shot 6-editor-com-teclado
  tap_text "Mais opções" && { shot 7-menu-da-nota; adb shell input keyevent 4; sleep 1; }
  shot 7b-editor
  tap_text "Estilo da nota" && { shot 8-estilo; adb shell input keyevent 4; sleep 1; }
  if tap_text "Lembrete"; then
    tap_text "Escreva" && adb shell input text "amanha%sas%s9"
    sleep 1
    shot 9-lembrete
    adb shell input keyevent 4; sleep 1
    adb shell input keyevent 4; sleep 1
  fi
  shot 9b-antes-de-voltar
  tap_text "Voltar" || true
  sleep 2
  shot 10-tela-com-nota
  # Seleção: segurar o card e abrir "Mais".
  if LONG=1 tap_text "Carne"; then
    shot 10b-selecao
    tap_text "Mais" && { shot 10c-selecao-mais; adb shell input keyevent 4; sleep 1; }
    tap_text "Cancelar seleção" || adb shell input keyevent 4
    sleep 1
  fi
fi
if tap_text "Menu"; then
  if tap_text "Ajustes"; then
    shot 11-ajustes
    tap_text "Aparência" && { shot 12-aparencia; adb shell input keyevent 4; sleep 1; }
  fi
  adb shell input keyevent 4; sleep 1
fi

# Os três widgets precisam estar registrados no Android.
# Modelos prontos: abre a mala de viagem (lista com subtarefas).
if tap_text "Menu"; then
  if tap_text "Modelos"; then
    shot 13-modelos
    if tap_text "Mala de viagem"; then
      sleep 2
      shot 14-lista-subtarefas
      tap_text "Mais opções" && { shot 15-menu-da-lista; adb shell input keyevent 4; sleep 1; }
      tap_text "Voltar" || true
      sleep 2
      shot 16-tela-final
    fi
  else
    adb shell input keyevent 4; sleep 1
  fi
fi

for widget in NotoWidgetProvider NotoQuickWidgetProvider NotoSummaryWidgetProvider NotoTodayWidgetProvider NotoTasksWidgetProvider NotoActionsWidgetProvider; do
  if adb shell dumpsys appwidget | grep -q "$widget"; then
    echo "OK: widget $widget registrado"
  else
    echo "::error::Widget $widget não aparece no Android"
    FAIL=1
  fi
done

adb logcat -d > "$OUT/logcat-completo.txt"
grep -E " $PKG|E flutter|AndroidRuntime|FATAL" "$OUT/logcat-completo.txt" > "$OUT/logcat-noto.txt" || true
if grep -qE "E flutter.*Unhandled Exception|FATAL EXCEPTION" "$OUT/logcat-noto.txt"; then
  echo "::error::O app deu erro ao abrir:"
  grep -E "E flutter|FATAL EXCEPTION" "$OUT/logcat-noto.txt" | head -6 | cut -c1-400 | sed 's/^/::error::/'
  FAIL=1
fi
ls -la $OUT
exit $FAIL
