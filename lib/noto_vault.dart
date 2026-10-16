import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'noto_editor_v2.dart';
import 'noto_models.dart';
import 'noto_store.dart';

const _forgot = '__esqueci__';

String _hash(String salt, String secret) =>
    sha256.convert(utf8.encode('$salt:$secret')).toString();

String _normalizeAnswer(String value) =>
    foldForSearch(value).trim().replaceAll(RegExp(r'\s+'), ' ');

String _newSalt() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
}

bool _checkPin(AppStore store, String pin) =>
    store.vaultPinHash != null &&
    _hash(store.vaultSalt, pin) == store.vaultPinHash;

bool _checkAnswer(AppStore store, String answer) =>
    store.vaultAnswerHash != null &&
    _hash(store.vaultSalt, _normalizeAnswer(answer)) == store.vaultAnswerHash;

Future<void> _setPin(AppStore store, String pin) async {
  store.vaultPinHash = _hash(store.vaultSalt, pin);
  await store.save();
}

/// Abre o cofre: cria na primeira vez, depois pede a senha.
Future<void> openVault(BuildContext context, AppStore store) async {
  if (!store.hasVault) {
    final created = await ensureVault(context, store);
    if (!created || !context.mounted) return;
  } else {
    final ok = await unlockVault(context, store);
    if (!ok || !context.mounted) return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => VaultPage(store: store)),
  );
}

/// Garante que o cofre existe. Se não existir, mostra a criação.
Future<bool> ensureVault(BuildContext context, AppStore store) async {
  if (store.hasVault) return true;
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _VaultSetupSheet(store: store),
  );
  return created == true;
}

/// Pede a senha. Tem "Esqueci a senha", que usa a pergunta secreta.
Future<bool> unlockVault(BuildContext context, AppStore store) async {
  while (context.mounted) {
    final pin = await _askPin(
      context,
      title: 'Cofre',
      message: 'Digite a senha do cofre.',
      allowForgot: true,
    );
    if (pin == null || !context.mounted) return false;
    if (pin == _forgot) return resetVaultPin(context, store);
    if (_checkPin(store, pin)) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha errada. Tente de novo.')),
    );
  }
  return false;
}

/// Redefine a senha respondendo a pergunta secreta. Nada é apagado.
Future<bool> resetVaultPin(BuildContext context, AppStore store) async {
  final answer = await showDialog<String>(
    context: context,
    builder: (_) => _AnswerDialog(question: store.vaultQuestion),
  );
  if (answer == null || !context.mounted) return false;
  if (!_checkAnswer(store, answer)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resposta diferente da cadastrada.')),
    );
    return false;
  }
  final pin = await _askNewPin(context);
  if (pin == null || !context.mounted) return false;
  await _setPin(store, pin);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha nova salva.')),
    );
  }
  return true;
}

/// Trocar a senha pelos Ajustes: pede a atual (ou a pergunta secreta).
Future<void> changeVaultPin(BuildContext context, AppStore store) async {
  final current = await _askPin(
    context,
    title: 'Senha atual',
    message: 'Digite a senha que você usa hoje.',
    allowForgot: true,
  );
  if (current == null || !context.mounted) return;
  if (current == _forgot) {
    await resetVaultPin(context, store);
    return;
  }
  if (!_checkPin(store, current)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha errada.')),
    );
    return;
  }
  final pin = await _askNewPin(context);
  if (pin == null || !context.mounted) return;
  await _setPin(store, pin);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha trocada.')),
    );
  }
}

Future<String?> _askNewPin(BuildContext context) async {
  final first = await _askPin(
    context,
    title: 'Senha nova',
    message: 'Escolha uma senha de 4 a 6 números.',
  );
  if (first == null || !context.mounted) return null;
  final second = await _askPin(
    context,
    title: 'Confirme a senha',
    message: 'Digite a mesma senha de novo.',
  );
  if (second == null || !context.mounted) return null;
  if (first != second) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('As senhas não batem. Tente de novo.')),
    );
    return null;
  }
  return first;
}

Future<String?> _askPin(
  BuildContext context, {
  required String title,
  required String message,
  bool allowForgot = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _PinDialog(title: title, message: message, allowForgot: allowForgot),
);

class _PinDialog extends StatefulWidget {
  const _PinDialog({
    required this.title,
    required this.message,
    required this.allowForgot,
  });

  final String title;
  final String message;
  final bool allowForgot;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = controller.text.trim();
    if (pin.length >= 4) Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Senha'),
          onSubmitted: (_) => _submit(),
        ),
        if (widget.allowForgot)
          TextButton(
            onPressed: () => Navigator.pop(context, _forgot),
            child: const Text('Esqueci a senha'),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('OK')),
    ],
  );
}

class _AnswerDialog extends StatefulWidget {
  const _AnswerDialog({required this.question});
  final String question;

  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Redefinir senha'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.question,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Sua resposta'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        const SizedBox(height: 6),
        const Text(
          'Maiúsculas e acentos não importam. Suas notas continuam no cofre.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('Continuar'),
      ),
    ],
  );
}

class _VaultSetupSheet extends StatefulWidget {
  const _VaultSetupSheet({required this.store});
  final AppStore store;

  @override
  State<_VaultSetupSheet> createState() => _VaultSetupSheetState();
}

class _VaultSetupSheetState extends State<_VaultSetupSheet> {
  final pin = TextEditingController();
  final confirm = TextEditingController();
  final question = TextEditingController();
  final answer = TextEditingController();
  String? error;

  static const suggestions = [
    'Nome do meu primeiro bicho de estimação',
    'Cidade onde eu nasci',
    'Nome da minha primeira escola',
  ];

  @override
  void dispose() {
    pin.dispose();
    confirm.dispose();
    question.dispose();
    answer.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final p = pin.text.trim();
    if (p.length < 4) {
      setState(() => error = 'A senha precisa ter de 4 a 6 números.');
      return;
    }
    if (p != confirm.text.trim()) {
      setState(() => error = 'As duas senhas não batem.');
      return;
    }
    if (question.text.trim().isEmpty || answer.text.trim().isEmpty) {
      setState(
        () => error = 'Escolha uma pergunta e responda. É com ela que você '
            'redefine a senha se esquecer.',
      );
      return;
    }
    final store = widget.store;
    store.vaultSalt = _newSalt();
    store.vaultQuestion = question.text.trim();
    store.vaultAnswerHash = _hash(
      store.vaultSalt,
      _normalizeAnswer(answer.text),
    );
    store.vaultPinHash = _hash(store.vaultSalt, p);
    await store.save();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Criar o cofre',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Notas no cofre somem da tela inicial, da busca, do calendário e '
            'do widget. Para abrir o cofre, segure o logo do Noto no topo da '
            'tela por 2 segundos e digite a senha.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Senha (4 a 6 números)',
            ),
          ),
          TextField(
            controller: confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Repita a senha'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pergunta secreta, para redefinir a senha se você esquecer:',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in suggestions)
                ActionChip(
                  label: Text(item),
                  onPressed: () => setState(() => question.text = item),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: question,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Pergunta',
              hintText: 'Escolha acima ou escreva a sua',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: answer,
            decoration: const InputDecoration(labelText: 'Resposta'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _create,
              child: const Text('Criar cofre'),
            ),
          ),
        ],
      ),
    ),
  );
}

class VaultPage extends StatelessWidget {
  const VaultPage({super.key, required this.store});
  final AppStore store;

  Future<void> _open(BuildContext context, Note note, {bool isNew = false}) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorPageV2(store: store, note: note, isNew: isNew),
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) {
      final items = store.notes
          .where((n) => n.locked && n.deletedAt == null)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cofre',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'O cofre está vazio.\nCrie uma nota aqui ou use '
                    '"Mover para o cofre" no menu de qualquer nota.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final note = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: Text(
                        note.title.trim().isEmpty ? 'Sem título' : note.title,
                      ),
                      subtitle: Text(
                        'Editada em ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
                      ),
                      onTap: () => _open(context, note),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opções',
                        onSelected: (value) async {
                          if (value == 'unlock') {
                            note.locked = false;
                            await store.save();
                            await store.refreshReminder(note);
                          }
                          if (value == 'trash') store.delete(note);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'unlock',
                            child: Text('Tirar do cofre'),
                          ),
                          PopupMenuItem(
                            value: 'trash',
                            child: Text('Mover para a lixeira'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Nova nota no cofre',
          onPressed: () => _open(
            context,
            Note(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              title: '',
              body: '',
              updatedAt: DateTime.now(),
              font: store.font,
              locked: true,
            ),
            isNew: true,
          ),
          child: const Icon(Icons.add_rounded),
        ),
      );
    },
  );
}
