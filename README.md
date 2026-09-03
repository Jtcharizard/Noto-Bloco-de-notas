<div align="center">
  <img src="assets/app_icon.png" width="128" alt="Ícone do Noto">

  # Noto

  **Um bloco de notas que combina com cada ideia.**

  Personalize cada nota com wallpapers, fontes e cores diferentes — tudo offline e direto no celular.

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
  [![Android](https://img.shields.io/badge/Android-APK-3DDC84?logo=android&logoColor=white)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
  [![Build APK](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml/badge.svg)](https://github.com/Jtcharizard/Noto-Bloco-de-notas/actions/workflows/gerar-apk.yml)
</div>

---

## Sobre o projeto

O **Noto** é um aplicativo de anotações feito em Flutter com foco em liberdade visual. Em vez de todas as notas terem a mesma aparência, cada uma pode receber sua própria identidade.

O app funciona sem conta e sem internet. As notas e preferências ficam armazenadas localmente no aparelho.

## Principais recursos

- Criação, edição, pesquisa e exclusão de notas
- Notas fixadas no topo
- Visualização em grade ou lista
- Wallpaper individual para cada nota
- **20 wallpapers originais** incluídos no app
- Upload de imagens da galeria como wallpaper
- Fontes, tamanhos e cores de texto personalizáveis
- Cores diferentes para cada nota
- Temas claro, escuro e automático
- Salvamento local e funcionamento totalmente offline

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
| Path Provider | Armazenamento das imagens importadas |
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

## Próximas ideias

- Pastas e etiquetas para organizar notas
- Checklist dentro das notas
- Backup e restauração
- Exportação de notas
- Bloqueio de notas por senha ou biometria

---

<div align="center">
  Desenvolvido por <a href="https://github.com/Jtcharizard">Jtcharizard</a> 💜
</div>
