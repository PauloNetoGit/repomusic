import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/rig.dart';
import '../state/factory_presets.dart';
import '../state/rig_controller.dart';
import 'theme.dart';
import 'widgets/block_card.dart';

class PresetsScreen extends StatefulWidget {
  const PresetsScreen({super.key, required this.controller});
  final RigController controller;

  @override
  State<PresetsScreen> createState() => _PresetsScreenState();
}

const _mine = 'Meus presets';

/// Remove acentos e caixa para a busca ("solo eletrico" acha "Solo Elétrico").
String _fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString();
}

class _PresetsScreenState extends State<PresetsScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _category; // null = todas

  RigController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Preset p) {
    if (_query.isEmpty) return true;
    final hay = _fold(
      [
        p.name,
        p.category ?? _mine,
        p.inspiration ?? '',
        for (final b in p.blocks) controller.defOf(b).displayName(b.model),
      ].join(' '),
    );
    return _fold(_query).split(' ').where((w) => w.isNotEmpty).every(hay.contains);
  }

  Future<String?> _askName(BuildContext context, {String title = 'Salvar preset', String initial = ''}) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('Salvar')),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = await _askName(context, initial: controller.presetName);
    if (name == null || name.trim().isEmpty) return;
    final exists = controller.userPresets.any((p) => p.name == name.trim());
    if (exists && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Substituir?'),
          content: Text('Já existe um preset chamado "${name.trim()}".'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Substituir')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await controller.savePresetAs(name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Preset "${name.trim()}" salvo')));
    }
  }

  Future<void> _load(BuildContext context, Preset p) async {
    if (controller.modified) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Descartar alterações?'),
          content: const Text('O rig atual tem alterações que não foram salvas como preset.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Carregar mesmo assim')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await controller.loadPreset(p);
    navigator.pop();
    if (p.tip != null) {
      messenger.showSnackBar(SnackBar(content: Text('${p.name}: ${p.tip}'), duration: const Duration(seconds: 6)));
    }
  }

  Future<void> _import(BuildContext context) async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final ctl = TextEditingController(text: clip?.text ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar preset'),
        content: TextField(
          controller: ctl,
          maxLines: 8,
          minLines: 4,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(hintText: 'Cole aqui o JSON do preset', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('Importar')),
        ],
      ),
    );
    if (text == null || !context.mounted) return;
    try {
      final p = await controller.importJson(text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Importado: ${p.name}')));
      }
    } on FormatException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _copy(BuildContext context, String json) async {
    await Clipboard.setData(ClipboardData(text: json));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JSON copiado. Cole em uma mensagem para compartilhar.')));
    }
  }

  Widget _tile(BuildContext context, Preset p, {bool showCategory = false}) {
    final current = p.name == controller.presetName;
    final summary = p.blocks.map((b) => controller.defOf(b).displayName(b.model)).join(' → ');
    final top = [
      if (showCategory) p.category ?? _mine,
      if (p.inspiration != null) 'Inspirado em ${formatInspiration(p.inspiration!)}',
    ].join('. ');
    return ListTile(
      leading: SizedBox(
        width: 24,
        child: Center(
          child: current
              ? const PilotLamp(on: true, size: 10)
              : Icon(p.factory ? Icons.music_note_outlined : Icons.person_outline, size: 20),
        ),
      ),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      isThreeLine: top.isNotEmpty,
      subtitle: Text(
        top.isEmpty ? summary : '$top\n$summary',
        maxLines: top.isEmpty ? 2 : 3,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _load(context, p),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'copy':
              await _copy(context, controller.exportJson(p));
            case 'rename':
              final n = await _askName(context, title: 'Renomear', initial: p.name);
              if (n != null) await controller.renameUserPreset(p, n);
            case 'delete':
              await controller.deleteUserPreset(p);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'copy', child: Text('Copiar JSON')),
          if (!p.factory) const PopupMenuItem(value: 'rename', child: Text('Renomear')),
          if (!p.factory) const PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }

  /// Monta a lista: com busca, uma lista plana; sem busca, seções por categoria.
  List<Widget> _items(BuildContext context) {
    final groups = <String, List<Preset>>{_mine: controller.userPresets};
    for (final c in factoryCategories) {
      groups[c] = [];
    }
    for (final p in controller.factoryPresets) {
      groups.putIfAbsent(p.category ?? catEssenciais, () => []).add(p);
    }
    final out = <Widget>[];
    if (_query.isNotEmpty) {
      final all = [
        for (final e in groups.entries)
          if (_category == null || e.key == _category) ...e.value,
      ];
      final found = all.where(_matches).toList();
      out.add(_Section('${found.length} resultado${found.length == 1 ? '' : 's'}'));
      for (final p in found) {
        out.add(_tile(context, p, showCategory: true));
      }
      if (found.isEmpty) {
        out.add(
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Nada encontrado. Tente o nome de uma música, artista ou estilo.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        );
      }
      return out;
    }
    for (final e in groups.entries) {
      if (_category != null && e.key != _category) continue;
      if (e.key != _mine && e.value.isEmpty) continue;
      out.add(_Section('${e.key} (${e.value.length})'));
      if (e.key == _mine && e.value.isEmpty) {
        out.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Nenhum ainda. Monte seu som e toque em "Salvar atual".',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        );
      }
      for (final p in e.value) {
        out.add(_tile(context, p));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Presets'),
          actions: [
            IconButton(tooltip: 'Importar JSON', icon: const Icon(Icons.download), onPressed: () => _import(context)),
            IconButton(
              tooltip: 'Copiar rig atual (JSON)',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _copy(context, controller.exportCurrentJson()),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _save(context),
          icon: const Icon(Icons.save_outlined),
          label: const Text('Salvar atual'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Buscar música, artista ou estilo',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final c in [null, _mine, ...factoryCategories])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(c ?? 'Todos'),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.only(bottom: 96), children: _items(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
    child: Text(text, style: AppText.section),
  );
}
