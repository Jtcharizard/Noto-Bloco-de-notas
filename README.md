# Noto — bloco de notas personalizável

App Flutter offline para Android/iOS. Permite criar, editar, pesquisar, colorir,
fixar e excluir notas. Inclui grade/lista, modo claro/escuro/sistema, cinco cores
principais, quatro famílias tipográficas, ajuste de tamanho do texto e quinze
wallpapers originais embutidos para uso offline.

## Rodar

1. Instale o Flutter e confirme com `flutter doctor`.
2. Na pasta do projeto, execute `flutter create .` para gerar as pastas nativas.
3. Execute `flutter pub get`.
4. Conecte o celular com depuração USB ou abra um emulador.
5. Execute `flutter run`.

Para gerar o APK: `flutter build apk --release`. O arquivo ficará em
`build/app/outputs/flutter-apk/app-release.apk`.

As notas e preferências ficam salvas apenas no aparelho, sem login e sem internet.

## Gerar pelo GitHub usando apenas o celular

O arquivo `.github/workflows/gerar-apk.yml` compila o aplicativo automaticamente.
Depois que os arquivos forem enviados a um repositório GitHub, abra **Actions**,
escolha **Gerar APK do Noto**, toque em **Run workflow** e, ao terminar, baixe o
artefato **Noto-APK**. Dentro dele estará o `app-release.apk` instalável.
