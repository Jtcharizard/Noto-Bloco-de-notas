<div align="center">
  <img src="assets/app_icon.png" width="128" alt="Ícone do Noto">

  # Noto

  **Um bloco de notas que combina com cada ideia.**

  Personalize cada nota com wallpapers, fontes e cores diferentes — tudo offline e direto no celular.

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
  [![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
  [![Versão](https://img.shields.io/badge/versão-2.7.0-8B5CF6)](https://github.com/Jtcharizard/Noto-Bloco-de-notas)
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

## Novidades da v3.2.0

- Tela inicial mais bonita: cartão de saudação com avatar, frase ou data e o resumo do dia; atalhos de pasta em pílula com contagem; barra do topo transparente sobre o fundo; botão "Nova nota" com nome; card de nota vazia com aviso.
- 8 temas prontos novos: Lavanda, Café, Neon, Menta, Cereja, Gelo, Grafite e Limão (16 no total).
- **Avatar**: um emoji seu no cartão de saudação (toque nele para trocar).
- **Frase do topo**: escreva uma frase para aparecer no lugar da data.
- **Cards de vidro**: cards translúcidos que deixam o fundo do app aparecer.

## Novidades da v3.1.0

- Corrigido: virar uma lista vazia em texto deixava um "- " sobrando. Agora a nota volta em branco.
- **Temas prontos**: Ajustes > Aparência tem 8 combinações de um toque (Meia-noite, Papel, Oceano, Floresta, Chiclete, Pôr do sol, Código e o padrão).
- **Saudação com seu nome**: "Boa noite, Ana" com a data no topo da tela inicial. O nome pode ser posto no fim do tutorial ou em Ajustes > Tela inicial.
- **Emoji nas pastas**: Menu > Pastas > ⋮ > Escolher emoji. Aparece nos atalhos, nos cards e dentro da nota.

## Novidades da v3.0.0

- Saiu "Ordenar linhas". Entrou **Excluir lista**: tira as tarefas da nota e deixa o texto (com Desfazer).
- **Nota de hoje** (como no Obsidian): Menu > Hoje abre ou cria a nota do dia na pasta Diário. Também no atalho do ícone do app.
- **Atalho na tela inicial** (como no Keep): ⋮ > Atalho na tela inicial põe a nota como ícone no celular.
- **Ir para seção** (como no Notion): pula para cada título da nota.
- **Arquivar ao terminar** (como no Todoist): marcou a última tarefa, aparece "Arquivar lista".
- **Links da nota** (como no Apple Notes): sites, e-mails e telefones da nota viram uma etiqueta para abrir com um toque.

## Novidades da v2.9.0

- Saíram a soma de valores em R$, a leitura em voz alta e "Limpar espaços".
- Botão de **estilo da nota** (paleta) separado, ao lado da barra de edição. Na barra ficou "Formatar texto" para título, lista, cor e alinhamento.
- Seleção de várias notas refeita: card marcado com borda e selo, barra com Pasta, Fixar, Arquivar, Lixeira e Mais. Mover e adicionar tag agora mostram as pastas e tags que já existem.
- Novo: **lista que desmarca todo dia** (rotina, remédios, academia).
- Novo: **colar o que copiei** como nota nova, direto no +.
- Novo: **proteger contra edição**: a nota abre só para ler até tocar em "Editar".

## Novidades da v2.8.0

**Nota mais arrumada**
- Barra de edição única, presa em cima do teclado: desfazer, refazer, negrito, itálico, virar lista, voz, inserir e **Aa**.
- Etiquetas logo abaixo do título (pasta e tags, lembrete, prazo, prioridade); é só tocar para mudar.
- Um só menu ⋮ com ações rápidas (fixar, favoritar, enviar, copiar) e o resto separado por assunto.
- O botão **Aa** junta o estilo da nota e a formatação do texto. Modo foco e contagem de palavras foram para o menu.

**Menu unificado**
- Na tela inicial, o botão **Menu** reúne tarefas, lembretes, calendário, pastas, tags, arquivadas, lixeira, backup e Ajustes.
- A busca avançada fica dentro da própria busca.
- Os Ajustes viraram categorias: Aparência, Tela inicial e cards, Notas e gestos, Backup e dados, Ajuda e sobre.

**Funções novas**
- Compartilhar a nota como imagem.
- Lembrete escrito do jeito que a gente fala: "amanhã às 9", "sexta 18h", "em 2 horas".
- "Desfazer" depois de arquivar ou apagar uma nota de dentro dela, e prazo com contagem nos cards ("vence amanhã").

**Tutorial novo** com ilustrações e animação leve.

Ilustrações do tutorial: [Fluent Emoji](https://github.com/microsoft/fluentui-emoji), da Microsoft, licença MIT.

## Novidades da v2.7.0

**Widget novo 2x2 "Resumo do dia":** tarefas a fazer, próximo lembrete e botões + Nota e + Lista. Os widgets ganharam as cores novas do Noto.

**Tela inicial:** tocar no nome do topo volta ao começo; busca por voz; no modo lista, notas agrupadas por Hoje, Ontem, Últimos 7 dias…

**Editor:** ordenar linhas de A a Z; limpar linhas vazias e espaços; MAIÚSCULAS, minúsculas e Iniciais no trecho selecionado.

**Listas de tarefas:** página "Todas as tarefas" com tudo que falta, para marcar direto; adicionar várias tarefas de uma vez; ordenar tarefas de A a Z.

**Lembretes e calendário:** adiar 10 min ou 1 hora pela notificação; prazo com lembrete um dia antes; calendário só com prazos e lembretes.

**Organização e busca:** várias palavras em qualquer ordem; resultados com a palavra no título primeiro; segurar uma pasta fixa ela no começo.

**Cofre:** olho para ver a senha digitada; "Trancar agora"; aviso quando alguém errou a senha.

**Personalização:** escolher o que deslizar para cada lado faz; cards compactos; esconder os atalhos de pastas.

**Dados:** data do último backup; exportar uma pasta inteira; limpar versões antigas e ver o espaço usado.

**Android:** o widget de nota abre a própria nota; atalho "Ditar uma nota" no ícone; compartilhar várias notas selecionadas.

## Novidades da v2.6.0

**Mais leve:** fontes reduzidas (só os caracteres usados em português), APK sem símbolos de depuração, tela inicial sem acessar o armazenamento a cada redesenho e código sem uso removido.

**Pedidos:** tutorial com uma página sobre o cofre e explicação completa ao criar o cofre; listas como 1- 2- 3-, 1 - e a) continuam sozinhas com Enter.

**Tela inicial:** voltar fecha a busca ou a seleção antes de sair; atalhos Favoritas, Com lembrete e Atrasadas; segurar o + cria o outro tipo de nota.

**Editor:** fixar no topo pelo menu da nota; informações da nota (criada, editada, palavras, leitura); ligar a lista de tarefas transforma itens de lista em tarefas.

**Listas de tarefas:** barra de progresso; marcar todas como feitas; copiar só o que falta; aviso quando tudo fica pronto.

**Lembretes e calendário:** lembrete todo mês; página de próximos lembretes; deslizar para trocar de mês e dias atrasados em vermelho.

**Organização e busca:** buscas recentes; #tag busca só nas tags; sugestões de tags ao organizar.

**Cofre:** escolher quando pede a senha de novo; busca dentro do cofre; sem print e conteúdo escondido nos apps recentes; espera de 30 s depois de 5 senhas erradas.

**Personalização:** o que o botão + faz; mostrar ou esconder a barra de atalhos; cor das notas novas.

**Dados:** restaurar backup juntando com as notas atuais; importar vários .txt e .md de uma vez; backup leva os ajustes e o cofre.

**Android:** receber arquivos de texto compartilhados; atalho "Última nota editada" no ícone; widget mostra quantas tarefas faltam.

## Novidades da v2.5.1

- Corrige o app que ficava carregando para sempre ao abrir (uma peça do Android tinha sido atualizada sozinha e quebrava no APK otimizado)
- Se algo der errado ao abrir, o app mostra uma mensagem com "Tentar de novo" em vez de carregar sem fim, e nunca grava por cima das notas
- Todo APK agora é aberto num Android virtual antes de ser publicado

## Novidades da v2.5.0

**Editor:** listas continuam sozinhas ao apertar Enter (-, 1., tarefas); ditado por voz; inserir data e hora; modo leitura; desmarcar todas as tarefas; apagar tarefas concluídas; barra de ferramentas compacta.

**Lembretes e prazos:** atalhos rápidos (em 1 hora, hoje às 20h, amanhã às 9h, segunda às 9h); prazo vencido em vermelho; filtro "Só atrasadas"; ordenar por prazo.

**Tela inicial:** contagem nos atalhos de pasta; trecho encontrado em destaque na busca; vibração ao selecionar.

**Seleção em lote:** juntar notas, fixar, adicionar tag, mover para o cofre e desfazer ao arquivar ou mandar para a lixeira.

**Android:** fixar nota na barra de notificações; atalhos ao segurar o ícone do app.

**Cofre:** bloqueia sozinho ao voltar depois de 30 segundos fora do app.

**Personalização:** preto puro no tema escuro; nome no topo da tela inicial; cantos dos cards; 2 ou 3 colunas; linhas de prévia; escolher pasta, tags e data nos cards; espaço entre as linhas do texto.

**Outros:** links clicáveis na visualização; estatísticas; exportar todas as notas num arquivo.

## Novidades da v2.4.0

- Notas sem título mostram a primeira linha como título
- Tocar na notificação do lembrete abre a nota (do cofre, pede a senha)
- Cards mostram o progresso da lista (2/5) e o próximo lembrete
- Busca com botão de limpar e aviso quando nada é encontrado
- Tela vazia com botão para criar a primeira nota
- Aviso para fazer backup depois de 30 dias sem
- Calendário cria nota com prazo no dia escolhido
- Lixeira: confirmar antes de apagar de vez, restaurar tudo e dias até sumir
- Apagar uma linha da lista tem "Desfazer"; vibração leve ao marcar tarefa
- "Cópia criada" com atalho para abrir a cópia
- Testes automáticos do salvamento em arquivo

## Novidades da v2.3.0

- 18 cores de destaque vivas, e o app inteiro passa a seguir a cor escolhida (antes o fundo continuava roxo)
- "Nota do widget" só aparece quando há notas para escolher

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
