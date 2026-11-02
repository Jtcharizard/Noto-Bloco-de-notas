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
import os, re, sys, xml.etree.ElementTree as ET
alvo = sys.argv[1].lower()
try:
    root = ET.parse('/tmp/tela.xml').getroot()
except Exception:
    sys.exit(0)
for node in root.iter('node'):
    label = (node.get('text') or '') + ' ' + (node.get('content-desc') or '')
    if os.environ.get('ONLYTEXT'):
        label = node.get('content-desc') or '' if not node.get('text') else node.get('text')
        if (node.get('class') or '').endswith('Button') and not node.get('text'):
            continue
    if os.environ.get('EXACT'):
        found = label.strip().lower() == alvo
    else:
        found = alvo in label.lower()
    if found:
        m = re.findall(r'\d+', node.get('bounds') or '')
        if len(m) == 4:
            x1, y1, x2, y2 = map(int, m)
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)
  if [ -z "$xy" ]; then
    echo "::warning::Não achei '$1' para tocar"
    grep -o 'text="[^"]*"\|content-desc="[^"]*"' /tmp/tela.xml 2>/dev/null | sed 's/^[^"]*"//; s/"$//' | grep -v '^$' | head -12 | sed 's/^/  tela: /'
    return 1
  fi
  if [ -n "$LONG" ]; then
    adb shell input swipe $xy $xy 900
  else
    adb shell input tap $xy
  fi
  sleep 1.5
}
# Toca num botão da mesma linha de um texto: tap_row "Leite" "Apagar tarefa"
# (use CHECKBOX para a caixa de marcar).
tap_row() {
  adb shell uiautomator dump /sdcard/tela.xml >/dev/null 2>&1
  adb shell cat /sdcard/tela.xml > /tmp/tela.xml 2>/dev/null
  local xy
  xy=$(python3 - "$1" "$2" <<'PY'
import re, sys, xml.etree.ElementTree as ET
texto, alvo = sys.argv[1], sys.argv[2].lower()
try:
    root = ET.parse('/tmp/tela.xml').getroot()
except Exception:
    sys.exit(0)
def box(n):
    m = re.findall(r'\d+', n.get('bounds') or '')
    return tuple(map(int, m)) if len(m) == 4 else None
linha = None
for n in root.iter('node'):
    if (n.get('text') or '').strip() == texto:
        linha = box(n)
        break
if not linha:
    sys.exit(0)
y = (linha[1] + linha[3]) // 2
for n in root.iter('node'):
    b = box(n)
    if not b or not (b[1] <= y <= b[3]) or b[2] - b[0] > 300:
        continue
    label = ((n.get('text') or '') + ' ' + (n.get('content-desc') or '')).lower()
    if (alvo == 'checkbox' and 'checkbox' in (n.get('class') or '').lower()) or (alvo != 'checkbox' and alvo in label):
        print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2)
        break
PY
)
  if [ -z "$xy" ]; then echo "::warning::Não achei '$2' na linha '$1'"; return 1; fi
  adb shell input tap $xy
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
# Apagar tarefas de todos os jeitos numa lista de compras.
# A tarefa tem que sumir da tela; se continuar, o teste reprova o build.
gone() {
  sleep 1
  if screen_text | grep -qx "$1"; then
    echo "::error::'$1' continua na tela ($2)"
    FAIL=1
  else
    echo "OK: '$1' apagada ($2)"
  fi
}
if tap_text "Menu"; then
  if tap_text "Modelos" && tap_text "Lista de compras"; then
    sleep 2
    shot 20-compras
    tap_text "Leite"; sleep 1; shot 21a-leite-tocada
    tap_row "Leite" "Apagar tarefa"; sleep 1; shot 21-x-leite; gone "Leite" "X da tarefa tocada"
    tap_text "Pão"; sleep 1
    tap_row "Pão" "Apagar tarefa"; sleep 1; shot 22-x-pao; gone "Pão" "X com teclado aberto"
    tap_text "Feijão"; sleep 1
    tap_row "Feijão" "Apagar tarefa"; sleep 1; shot 23-x-feijao; gone "Feijão" "X de novo na mesma lista"
    # Tarefa marcada também só sai pelo X da linha tocada.
    tap_row "Arroz" "CHECKBOX"; sleep 1
    tap_text "Arroz"; sleep 1
    tap_row "Arroz" "Apagar tarefa"; sleep 1; shot 24-x-arroz-marcada; gone "Arroz" "X numa tarefa marcada"
    # O menu da lista não tem outro jeito de apagar tarefa.
    if tap_text "Mais opções"; then
      adb shell input swipe $((W/2)) $((H*80/100)) $((W/2)) $((H*35/100)) 300; sleep 1
      shot 24b-menu-sem-apagar
      for proibido in "Apagar feitas" "Excluir lista"; do
        if screen_text | grep -qiF "$proibido"; then echo "::error::O menu da lista ainda tem '$proibido'"; FAIL=1; fi
      done
      adb shell input keyevent 4; sleep 1
    fi
    tap_text "Voltar" || adb shell input keyevent 4
    sleep 2
    shot 25-home-depois
    if tap_text "Compras"; then
      sleep 2; shot 26-reaberta
      for t in Leite Pão Feijão Arroz; do gone "$t" "depois de reabrir"; done
      tap_text "Voltar" || adb shell input keyevent 4
      sleep 1
    fi
  fi
fi

# Toca no campo da primeira tarefa (à direita da primeira caixa de marcar).
tap_first_task() {
  adb shell uiautomator dump /sdcard/tela.xml >/dev/null 2>&1
  adb shell cat /sdcard/tela.xml > /tmp/tela.xml 2>/dev/null
  local xy
  xy=$(python3 - <<'PY'
import re, xml.etree.ElementTree as ET
try:
    root = ET.parse('/tmp/tela.xml').getroot()
except Exception:
    raise SystemExit(0)
for n in root.iter('node'):
    if 'checkbox' in (n.get('class') or '').lower():
        m = re.findall(r'\d+', n.get('bounds') or '')
        if len(m) == 4:
            x1, y1, x2, y2 = map(int, m)
            print(x2 + 160, (y1 + y2) // 2)
            break
PY
)
  if [ -z "$xy" ]; then echo "::warning::Não achei a caixa da primeira tarefa"; return 1; fi
  adb shell input tap $xy
  sleep 1.5
}
count_checkboxes() {
  adb shell uiautomator dump /sdcard/tela.xml >/dev/null 2>&1
  adb shell cat /sdcard/tela.xml 2>/dev/null | grep -o 'class="[^"]*CheckBox"' | wc -l
}

# Menu de criar: só "Em branco" e "Lista de tarefas" (não há modelo salvo).
# Depois, uma lista com UMA tarefa só: o X apaga e a nota volta em branco.
if tap_text "Nova nota"; then
  sleep 1
  shot 29-menu-criar
  expect_text "Em branco" "menu de criar"
  expect_text "Lista de tarefas" "menu de criar"
  for proibido in "Colar o que copiei" "Usar um modelo"; do
    if screen_text | grep -qiF "$proibido"; then echo "::error::O menu de criar tem '$proibido'"; FAIL=1; fi
  done
  if tap_text "Lista de tarefas"; then
    sleep 2
    tap_first_task
    adb shell input text "Pilhas"
    sleep 1
    shot 30-uma-tarefa
    if screen_text | grep -qx "Pilhas"; then
      tap_text "Pilhas"; sleep 1
      tap_row "Pilhas" "Apagar tarefa"; sleep 1
      shot 31-uma-tarefa-apagada
      gone "Pilhas" "a única tarefa da nota"
      left=$(count_checkboxes)
      if [ "$left" != "0" ]; then
        echo "::error::Depois de apagar a única tarefa sobrou $left caixa(s) de marcar"
        FAIL=1
      else
        echo "OK: nota com uma tarefa só voltou em branco"
      fi
    else
      echo "::error::Não consegui escrever a tarefa única"
      screen_text | head -20 | sed 's/^/  tela: /'
      FAIL=1
    fi
    tap_text "Voltar" || adb shell input keyevent 4
    sleep 2
    shot 32-depois-da-tarefa-unica
    # Ao sair, a tarefa apagada não pode voltar (a nota nova ficou vazia).
    if screen_text | grep -qiF "Pilhas"; then
      echo "::error::A tarefa única apagada voltou depois de sair da nota"
      FAIL=1
    else
      echo "OK: a tarefa única apagada não voltou ao sair"
    fi
  else
    adb shell input keyevent 4; sleep 1
  fi
fi

# Avatares prontos no cartão de saudação.
if tap_text "Trocar avatar"; then
  shot 27-avatares
  tap_text "Raposa" && { sleep 1; shot 28-com-avatar; }
fi

# Modelos prontos: abre a mala de viagem (lista com subtarefas).
if tap_text "Menu"; then
  if tap_text "Modelos"; then
    shot 13-modelos
    if tap_text "Mala de viagem"; then
      sleep 2
      shot 14-lista-subtarefas
      tap_text "Roupas" && sleep 1
      shot 14b-tarefa-tocada
      tap_text "Mais opções" && { shot 15-menu-da-lista; adb shell input keyevent 4; sleep 1; }
      tap_text "Voltar" || true
      sleep 2
      shot 16-tela-final
    fi
  else
    adb shell input keyevent 4; sleep 1
  fi
fi

# Passeio pelas novidades da 4.5. Só tira prints; se algo travar, o log do
# Flutter no fim reprova o build.
swipe_up() { adb shell input swipe $((W/2)) $((H*80/100)) $((W/2)) $((H*30/100)) 300; sleep 1; }
if tap_text "Menu"; then
  if tap_text "Foco"; then
    sleep 1; shot 40-timer-de-foco
    if EXACT=1 tap_text "Começar"; then
      sleep 3
      # Na primeira vez o Android pede a permissão de alarmes exatos.
      if screen_text | grep -qiE "alarms|alarmes"; then
        shot 41a-permissao-alarme
        adb shell input keyevent 4; sleep 2
      fi
      shot 41-timer-rodando
      EXACT=1 tap_text "Parar" || true
    fi
    adb shell input keyevent 4
    sleep 2
  else
    adb shell input keyevent 4; sleep 1
  fi
fi
if tap_text "Carne"; then
  sleep 2
  if tap_text "Mais opções"; then
    swipe_up
    if tap_text "Ler rolando"; then
      sleep 4; shot 42-ler-rolando
      tap_text "Voltar" || adb shell input keyevent 4
      sleep 1
    else
      adb shell input keyevent 4; sleep 1
    fi
  fi
  if tap_text "Mais opções"; then
    swipe_up
    if tap_text "Meta de palavras"; then
      sleep 1; shot 43-meta-de-palavras
      tap_text "250" || tap_text "Salvar" || adb shell input keyevent 4
      sleep 2; shot 43b-meta-na-nota
    else
      adb shell input keyevent 4; sleep 1
    fi
  fi
  if tap_text "Estilo da nota"; then
    swipe_up
    tap_text "Pautado" || true
    tap_text "Pêssego" || true
    sleep 1; shot 44-estilo-papel-degrade
    adb shell input keyevent 4; sleep 1
    shot 45-nota-pautada-degrade
  fi
  tap_text "Voltar" || adb shell input keyevent 4
  sleep 2
  shot 46-card-com-degrade
fi
if tap_text "Menu"; then
  if tap_text "Ajustes"; then
    if tap_text "Notas, gestos"; then shot 47-ajustes-notas; swipe_up; shot 47b-ajustes-notas; adb shell input keyevent 4; sleep 1; fi
    if tap_text "Aparência"; then swipe_up; shot 48-ajustes-aparencia; adb shell input keyevent 4; sleep 1; fi
    adb shell input keyevent 4; sleep 1
  else
    adb shell input keyevent 4; sleep 1
  fi
fi

# Sem backup automático: o Android não pode copiar as notas sozinho.
if adb shell dumpsys package $PKG | grep -m1 "pkgFlags" | grep -q "ALLOW_BACKUP"; then
  echo "::error::O backup automático do Android está ligado no APK"
  FAIL=1
else
  echo "OK: backup automático do Android desligado"
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
