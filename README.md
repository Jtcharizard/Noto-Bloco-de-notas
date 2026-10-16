<div align="center">
  <img src="assets/app_icon.png" width="128" alt="Ícone do Noto">

  # Noto

  **Um bloco de notas que combina com cada ideia.**

  Personalize cada nota com wallpapers, fontes e cores diferentes — tudo offline e direto no celular.

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
  [![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
  [![Versão](https://img.shields.io/badge/versão-2.2.0-8B5CF6)](https://github.com/Jtcharizard/Noto-Bloco-de-notas)
  [![Build APK](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml/badge.svg)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
</div>

---

## Sobre o projeto

O **Noto** é um aplicativo de anotações feito em Flutter com foco em liberdade visual. Em vez de todas as notas terem a mesma aparência, cada uma pode receber sua própria identidade.

O app funciona sem conta e sem internet. As notas e preferências ficam armazenadas localmente no aparelho.

## Principais recursos

- Criação, edição, pesquisa, duplicação, arquivamento e lixeira
- Exclusão com opção de desfazer
- Pastas, etiquetas, favoritos e notas fixadas no topo
- Visualização em grade ou lista
- Checklists marcáveis, reordenáveis e com indicador de progresso
- Lembretes com notificações
- Wallpaper individual para cada nota
- **20 wallpapers originais** incluídos no app
- Upload de imagens da galeria para a tela inicial ou para uma nota específica
- Ajustes de brilho e desfoque dos wallpapers
- Fontes, tamanhos e cores de texto personalizáveis
- Cores diferentes para cada nota
- Temas claro, escuro e automático
- Dois widgets para a tela inicial, com escolha da nota exibida
- Backup e restauração das notas, configurações e imagens
- Compartilhamento e exportação em TXT
- Apresentação inicial e tela Sobre
- Salvamento local e funcionamento totalmente offline

## Novidades da v2.2.0

- Assinatura fixa: a partir desta versão, as atualizações instalam por cima sem apagar nada
- Notas salvas em arquivo próprio, com cópia da última versão boa
- Lembretes corrigidos: o app pede permissão para notificar, toca no horário exato e volta a funcionar depois de reiniciar o celular
- Fuso horário automático
- APK bem menor (um arquivo por tipo de celular)
- Modo lista, texto maior nos cards e ajuste de escurecer e desfocar o fundo do app

## Novidades da v2.1.0

- Menu de criar mais simples: nota em branco, lista de tarefas e seus modelos
- Busca que ignora acentos e maiúsculas, inclusive dentro de tabelas e código
- Pastas e tags agora podem ser renomeadas e apagadas
- Tarefas marcadas descem para o fim da lista, com opção de esconder
- Lembretes que repetem: todo dia, dias úteis ou toda semana
- Compartilhe texto de outros apps direto para o Noto
- Lixeira se esvazia sozinha depois de 30 dias
- Cofre escondido com senha para notas privadas
- Data de criação das notas, com ordenação por ela
- Exportação em PDF
- Tutorial de uso na primeira abertura e dicas no momento certo

## Novidades da v2.0.0

- Saiu o Noto Pulse; a tela inicial ficou mais limpa
- Contagem de tarefas corrigida (antes mostrava zero nas listas novas)
- Enter numa tarefa cria a próxima; Enter numa tarefa vazia volta para texto
- Desfazer, histórico e links agora atualizam também as listas de tarefas
- Liga e desliga a lista de tarefas pelo menu Inserir, sem travar a nota
- Lembretes: não trava mais com lembrete antigo, avisa se o horário já passou e some depois de tocar
- Atalhos de pasta na tela inicial e ação "Mover para a lixeira" na seleção em lote
- Modo foco não fica mais ligado sozinho na próxima nota
- Sem aviso chato de título repetido; emoji da nota salva enquanto você digita
- Calendário mostra lembretes; notas arquivadas abrem com um toque
- Lixeira com botão "Esvaziar"; backup agora inclui modelos e capas
- Escolha de nota do widget voltou aos Ajustes; o widget "Nova nota" abre direto uma nota em branco
- Textos do app revisados em português claro

## Novidades da v1.9.0

- Texto comum e tarefas com checkbox agora convivem na mesma nota.
- Cada linha pode virar texto ou tarefa, ser reordenada e removida pelo menu da linha.
- Barra do editor mais limpa, com ações reunidas em **Inserir**, **Formatar** e **Ferramentas**.
- Ícones voltam a respeitar contraste e cores do tema.
- Calendário inicializa corretamente em português, sem abrir uma tela em branco.

## Novidades da v1.8.0

- Barras e painéis respeitam a navegação do Android com margem adicional.
- Botões e controles tonais seguem a cor escolhida em Aparência.
- Checklist volta a exibir caixas clicáveis; notas formadas por tarefas Markdown são reconhecidas automaticamente. O menu permite alternar checklist/texto.
- Código em painel editável com linguagem, números de linha (sem quebra), copiar, quebra de linha e exclusão confirmada. Blocos antigos delimitados por três crases são convertidos ao abrir.
- Ordenação por título A–Z/Z–A ou data recente/antiga, mantendo fixadas no topo.
- Segure uma nota para selecionar várias e mover, favoritar ou arquivar em lote.
- Prévia de fontes com uma frase editável.

## Novidades da v1.7.0

- Tabelas visuais com células editáveis, rolagem horizontal e inclusão/remoção de linhas e colunas. Tabelas Markdown anteriores são convertidas ao abrir a nota.
- Desfazer/refazer, buscar/substituir (incluindo tabelas em substituir tudo), alinhamento do texto e cor/marca-texto no trecho selecionado.
- 10 fontes adicionais disponíveis offline: Roboto Slab, Merriweather, Ubuntu, PT Sans, Inconsolata, Dosis, Anton, Shadows Into Light, Amatic SC e Indie Flower.
- Paleta violeta da logo e 8 cores vivas opcionais em Aparência.
- Salvamento automático com indicador, diário de rascunhos para recuperação, última posição do cursor e rolagem, fechar teclado, contagem da seleção, copiar nota, aviso de título repetido, atalhos fixados na barra, preferências de foco/atalhos e confirmação ao apagar tabelas preenchidas.
- Dados de tabelas e formatação incluídos em backup, duplicação, modelos e histórico.

As tabelas ficam abaixo do texto da nota. Toque em uma célula para editar. O menu da tabela insere e remove linhas/colunas a partir da célula selecionada. O alinhamento aplica-se ao texto da nota; cores, fontes e marca-texto podem ser aplicados à seleção. TXT e Markdown preservam os textos e as tabelas; o backup Noto preserva também os estilos.

## Novidades da v0.4.5

- Arquive, duplique ou desfaça a exclusão de uma nota
- Acompanhe o progresso e arraste itens para reorganizar checklists
- Escolha qual nota aparece no widget
- Crie um backup completo em arquivo `.noto` e restaure quando precisar
- Controle o escurecimento e o desfoque dos fundos
- Conheça o app pela nova apresentação inicial

## Galeria de wallpapers

<div align="center">
  <img src="assets/wallpapers/celestial_dragon.png" width="23%" alt="Dragão celestial">
  <img src="assets/wallpapers/neon_city.png" width="23%" alt="Cidade neon">
  <img src="assets/wallpapers/black_hole.png" width="23%" alt="Buraco negro">
  <img src="assets/wallpapers/crystal_kingdom.png" width="23%" alt="Reino de cristal">
</div>

<div align="center">
  <sub>Além desses, o app inclui natureza, estrelas, aurora, oceano, carros, pixel art e outros estilos.</sub>
</div>

## Tecnologias

| Tecnologia | Uso no projeto |
|---|---|
| Flutter e Dart | Interface e lógica do aplicativo |
| SharedPreferences | Persistência local das notas e configurações |
| Image Picker | Escolha de wallpapers pela galeria |
| File Picker | Importação dos arquivos de backup |
| Path Provider | Armazenamento das imagens importadas |
| Local Notifications | Lembretes das notas |
| Home Widget | Widgets para a tela inicial do Android |
| GitHub Actions | Compilação automática do APK |

## Baixar o APK

1. Abra a página de [Actions](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml).
2. Entre na execução mais recente com o símbolo verde.
3. Baixe o artefato **Noto-APK**.
4. Extraia o arquivo ZIP e instale o APK no Android.

> O Android pode pedir permissão para instalar aplicativos de fontes externas.

## Executar o projeto

Pré-requisitos: [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado e um dispositivo Android ou emulador configurado.

```bash
git clone https://github.com/Jtcharizard/Noto-Bloco-de-notas.git
cd Noto-Bloco-de-notas
flutter create .
flutter pub get
flutter run
```

Para gerar um APK de produção:

```bash
flutter build apk --release
```

O arquivo será criado em `build/app/outputs/flutter-apk/app-release.apk`.

<div align="center">
  Desenvolvido por <a href="https://github.com/Jtcharizard">Jtcharizard</a> 🧡
</div>
