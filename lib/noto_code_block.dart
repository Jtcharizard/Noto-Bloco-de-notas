import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotoCodeBlock extends StatefulWidget {
  const NotoCodeBlock({
    super.key,
    required this.data,
    required this.onChanged,
    required this.onDelete,
  });
  final Map<String, dynamic> data;
  final VoidCallback onChanged, onDelete;
  @override
  State<NotoCodeBlock> createState() => _NotoCodeBlockState();
}

class _NotoCodeBlockState extends State<NotoCodeBlock> {
  late final controller = TextEditingController(
    text: widget.data['text'] as String? ?? '',
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wrap = widget.data['wrap'] == true;
    final lines = controller.text.split('\n');
    return Card(
      color: cs.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.code),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: widget.data['language'] as String? ?? 'texto',
                    items:
                        [
                              'texto',
                              'dart',
                              'python',
                              'javascript',
                              'typescript',
                              'html',
                              'css',
                              'json',
                              'sql',
                              'java',
                              'c',
                              'cpp',
                              'bash',
                            ]
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) {
                      setState(() => widget.data['language'] = v);
                      widget.onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'Copiar código',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: controller.text),
                    );
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado')),
                      );
                  },
                ),
                IconButton(
                  tooltip: 'Apagar bloco de código',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (controller.text.isNotEmpty) {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Apagar código?'),
                          content: const Text('O bloco será removido da nota.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Apagar'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !mounted) return;
                    }
                    widget.onDelete();
                  },
                ),
              ],
            ),
            Row(
              children: [
                Switch(
                  value: wrap,
                  onChanged: (v) {
                    setState(() => widget.data['wrap'] = v);
                    widget.onChanged();
                  },
                ),
                const Text('Quebrar linhas'),
                const Spacer(),
                Text('${lines.length} linhas'),
              ],
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                Widget editor(double width) => SizedBox(
                  width: width,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            List.generate(
                              lines.length,
                              (i) => '${i + 1}',
                            ).join('\n'),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: 'FiraCode',
                              fontSize: 14,
                              height: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 3,
                          maxLines: null,
                          autocorrect: false,
                          enableSuggestions: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            fontFamily: 'FiraCode',
                            fontSize: 14,
                            height: 1.5,
                            color: cs.onSurface,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Cole ou escreva seu código',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (v) {
                            widget.data['text'] = v;
                            widget.onChanged();
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                );
                if (wrap) return editor(constraints.maxWidth);
                final longest = lines.fold<int>(
                  0,
                  (n, s) => s.length > n ? s.length : n,
                );
                final width = (longest * 9.0 + 70).clamp(
                  constraints.maxWidth,
                  20000.0,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: editor(width),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
