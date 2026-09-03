<div align="center">
  <img src="assets/app_icon.png" width="128" alt="Ícone do Noto">

  # Noto

  **Um bloco de notas que combina com cada ideia.**

  Personalize cada nota com wallpapers, fontes e cores diferentes — tudo offline e direto no celular.

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
  [![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
  [![Versão](https://img.shields.io/badge/versão-0.4.5-F28C28)](https://github.com/Jtcharizard/Noto-Bloco-de-notas)
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
