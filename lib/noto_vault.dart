import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'noto_editor.dart';
import 'noto_features.dart';
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
    await showVaultGuide(context);
    if (!context.mounted) return;
  } else {
    // Erros de antes desta abertura (os seus erros agora não contam).
    final wrong = store.vaultWrongSinceOpen;
    final at = store.vaultLastWrongAt;
    final ok = await unlockVault(context, store);
    if (!ok || !context.mounted) return;
    store.vaultWrongSinceOpen = 0;
    store.vaultLastWrongAt = null;
    await store.save();
    if (wrong > 0 && context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: Text(
            wrong == 1
                ? 'Erraram a senha 1 vez'
                : 'Erraram a senha $wrong vezes',
          ),
          content: Text(
            'Desde a última vez que o cofre foi aberto'
            '${at == null ? '' : ', a última em ${DateFormat("dd/MM 'às' HH:mm").format(at)}'}. '
            'Se não foi você, troque a senha no menu ⋮ do cofre.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ok'),
            ),
          ],
        ),
      );
    }
    if (!context.mounted) return;
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
    final wait = store.vaultWaitSeconds;
    if (wait > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Muitas tentativas. Espere $wait segundos.')),
      );
      return false;
    }
    final ok = _checkPin(store, pin);
    store.registerVaultAttempt(ok);
    if (ok) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          store.vaultWaitSeconds > 0
              ? 'Senha errada 5 vezes. Espere 30 segundos.'
              : 'Senha errada. Tente de novo.',
        ),
      ),
    );
    if (store.vaultWaitSeconds > 0) return false;
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

/// Trocar a senha (botão dentro do cofre): pede a atual ou a pergunta secreta.
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
  bool visible = false;

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
          obscureText: !visible,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Senha',
            suffixIcon: IconButton(
              tooltip: visible ? 'Esconder senha' : 'Mostrar senha',
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => visible = !visible),
            ),
          ),
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

/// Confere a senha do cofre (usado pela tela de bloqueio).
bool checkVaultPin(AppStore store, String pin) => _checkPin(store, pin);

/// Conta a tela como "cofre aberto" enquanto ela existir.
class VaultSessionGuard extends StatefulWidget {
  const VaultSessionGuard({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;

  @override
  State<VaultSessionGuard> createState() => _VaultSessionGuardState();
}

class _VaultSessionGuardState extends State<VaultSessionGuard> {
  @override
  void initState() {
    super.initState();
    widget.store.vaultScreenOpened();
  }

  @override
  void dispose() {
    widget.store.vaultScreenClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Tela que cobre o app quando você volta com o cofre aberto.
class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({
    super.key,
    required this.store,
    required this.onLeave,
  });
  final AppStore store;
  final VoidCallback onLeave;

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _try() {
    final wait = widget.store.vaultWaitSeconds;
    if (wait > 0) {
      setState(() => error = 'Muitas tentativas. Espere $wait s.');
      return;
    }
    final ok = checkVaultPin(widget.store, controller.text.trim());
    widget.store.registerVaultAttempt(ok);
    if (ok) {
      widget.store.releaseVaultLock();
    } else {
      setState(
        () => error = widget.store.vaultWaitSeconds > 0
            ? 'Senha errada 5 vezes. Espere 30 s.'
            : 'Senha errada.',
      );
      controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 52, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'Cofre bloqueado',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Você saiu do app com o cofre aberto. Digite a senha para continuar.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      errorText: error,
                    ),
                    onSubmitted: (_) => _try(),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(onPressed: _try, child: const Text('Abrir')),
                TextButton(
                  onPressed: widget.onLeave,
                  child: const Text('Sair do cofre'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Explica como o cofre funciona. Aparece ao criar o cofre e no botão ⓘ dele.
Future<void> showVaultGuide(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheetContext) {
    final cs = Theme.of(sheetContext).colorScheme;
    Widget item(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
        children: [
          Text(
            'Como funciona o cofre',
            style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          item(
            Icons.touch_app_outlined,
            'Para abrir',
            'Segure o logo do Noto, no topo da tela inicial, por 2 segundos. '
                'Depois digite a senha.',
          ),
          item(
            Icons.lock_outline_rounded,
            'Para guardar uma nota',
            'No menu ⋮ da nota, toque em "Mover para o cofre". Também dá '
                'para criar notas direto aqui dentro, no +.',
          ),
          item(
            Icons.visibility_off_outlined,
            'O que fica escondido',
            'Notas do cofre não aparecem na tela inicial, na busca, no '
                'calendário, no widget nem no resumo do dia. Lembretes delas '
                'avisam só "Lembrete do Noto", sem mostrar o texto.',
          ),
          item(
            Icons.timer_outlined,
            'Trava sozinho',
            'Se você sair do app com o cofre aberto, ele pede a senha de novo '
                'ao voltar. O tempo dá para mudar no menu ⋮ do cofre. Com o '
                'cofre aberto, o celular não deixa tirar print.',
          ),
          item(
            Icons.help_outline_rounded,
            'Esqueceu a senha?',
            'Toque em "Esqueci a senha" e responda a pergunta secreta. Você '
                'cria uma senha nova e nenhuma nota é apagada.',
          ),
          item(
            Icons.warning_amber_rounded,
            'Atenção com o backup',
            'O arquivo de backup leva as notas do cofre junto, sem senha. '
                'Guarde o arquivo num lugar seguro.',
          ),
          FilledButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  },
);

class VaultPage extends StatefulWidget {
  const VaultPage({super.key, required this.store});
  final AppStore store;

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  AppStore get store => widget.store;
  bool searching = false;
  String query = '';

  Future<void> _open(Note note, {bool isNew = false}) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EditorPage(store: store, note: note, isNew: isNew),
    ),
  );

  Future<void> _pickLockTime() async {
    const options = [
      (0, 'Assim que sair do app'),
      (30, 'Depois de 30 segundos'),
      (120, 'Depois de 2 minutos'),
      (600, 'Depois de 10 minutos'),
    ];
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Pedir a senha de novo',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            for (final option in options)
              RadioListTile<int>(
                value: option.$1,
                groupValue: store.vaultLockSeconds,
                title: Text(option.$2),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null) return;
    store.vaultLockSeconds = picked;
    await store.save();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) {
      final folded = foldForSearch(query.trim());
      final items = store.notes.where((n) {
        if (!n.locked || n.deletedAt != null) return false;
        if (folded.isEmpty) return true;
        return foldForSearch(n.title).contains(folded) ||
            foldForSearch(n.body).contains(folded);
      }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return VaultSessionGuard(
        store: store,
        child: Scaffold(
          appBar: AppBar(
            title: searching
                ? TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Buscar no cofre',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onChanged: (value) => setState(() => query = value),
                  )
                : const Text(
                    'Cofre',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
            actions: [
              IconButton(
                tooltip: searching ? 'Fechar busca' : 'Buscar no cofre',
                icon: Icon(
                  searching ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: () => setState(() {
                  searching = !searching;
                  if (!searching) query = '';
                }),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções do cofre',
                onSelected: (value) {
                  if (value == 'lock') {
                    Navigator.popUntil(context, (route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cofre trancado')),
                    );
                    return;
                  }
                  if (value == 'guide') showVaultGuide(context);
                  if (value == 'lock-time') _pickLockTime();
                  if (value == 'pin') changeVaultPin(context, store);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'lock',
                    child: ListTile(
                      leading: Icon(Icons.lock_rounded),
                      title: Text('Trancar agora'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'guide',
                    child: ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('Como funciona o cofre'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'lock-time',
                    child: ListTile(
                      leading: Icon(Icons.timer_outlined),
                      title: Text('Quando pedir a senha'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'pin',
                    child: ListTile(
                      leading: Icon(Icons.password_rounded),
                      title: Text('Trocar senha'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      query.trim().isNotEmpty
                          ? 'Nada encontrado no cofre.'
                          : 'O cofre está vazio.\nCrie uma nota aqui ou use '
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
                        title: Text(displayTitle(note)),
                        subtitle: Text(
                          'Editada em ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
                        ),
                        onTap: () => _open(note),
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
        ),
      );
    },
  );
}
