import 'package:flutter/material.dart';

import '../engine/catalog.dart';
import '../state/rig_controller.dart';
import 'theme.dart';

/// Abre o catálogo e adiciona o bloco escolhido. Retorna o uid do bloco novo.
Future<String?> showCatalog(BuildContext context, RigController c) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _CatalogView(controller: c)),
  );
}

class _CatalogView extends StatelessWidget {
  const _CatalogView({required this.controller});
  final RigController controller;

  void _add(BuildContext context, BlockDef def, int model) {
    final b = controller.addBlock(def, model);
    Navigator.of(context).pop(b.uid);
  }

  @override
  Widget build(BuildContext context) {
    final cat = controller.catalog;
    final groups = <String, List<BlockDef>>{};
    for (final p in cat.inCategory('pedal')) {
      groups.putIfAbsent(p.group, () => []).add(p);
    }
    final amp = cat.byId('amp');
    final combo = cat.byId('combo');
    final cab = cat.byId('cab');

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Adicionar à pedaleira', style: AppText.gear(28)),
            ),
          ),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Pedais'),
              Tab(text: 'Amplificadores'),
              Tab(text: 'Cubos'),
              Tab(text: 'Caixas'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                CustomScrollView(
                  slivers: [
                    for (final g in groups.entries) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                          child: Text(g.key, style: AppText.section),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => _PedalTile(def: g.value[i], onTap: () => _add(context, g.value[i], 0)),
                            childCount: g.value.length,
                          ),
                        ),
                      ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
                _modelList(context, amp),
                _modelList(context, combo),
                _modelList(context, cab),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modelList(BuildContext context, BlockDef? def) {
    if (def == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
          child: Text(def.desc, style: AppText.caption.copyWith(fontSize: 13.5)),
        ),
        for (var m = 0; m < def.models.length; m++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ModelTile(
              category: def.category,
              title: def.models[m].name,
              subtitle: def.models[m].desc,
              onTap: () => _add(context, def, m),
            ),
          ),
      ],
    );
  }
}

/// Miniatura de pedal: gabinete colorido com o nome serigrafado.
class _PedalTile extends StatelessWidget {
  const _PedalTile({required this.def, required this.onTap});
  final BlockDef def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(def.color);
    final fg = onColor(color);
    return Semantics(
      button: true,
      label: 'Adicionar ${def.name}',
      child: Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color.lerp(color, Colors.white, 0.1)!, Color.lerp(color, Colors.black, 0.22)!],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(def.name, maxLines: 2, style: AppText.gear(21, color: fg)),
                      const Spacer(),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [Color(0xFFF2F2F4), Color(0xFF9A9AA2), Color(0xFF55555C)],
                              center: Alignment(-0.3, -0.35),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Text(
                  def.desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de modelo (amplificador, cubo ou caixa) com uma amostra do acabamento.
class _ModelTile extends StatelessWidget {
  const _ModelTile({required this.category, required this.title, required this.subtitle, required this.onTap});
  final String category;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final swatch = switch (category) {
      'amp' => const BoxDecoration(
        color: AppColors.tolex,
        border: Border(bottom: BorderSide(color: AppColors.brass, width: 10)),
      ),
      'combo' => const BoxDecoration(
        color: AppColors.tweed,
        border: Border(top: BorderSide(color: AppColors.brass, width: 8)),
      ),
      _ => const BoxDecoration(color: Color(0xFF17171A)),
    };
    return Material(
      color: AppColors.surface2,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(width: 48, height: 48, decoration: swatch),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.gear(21)),
                    const SizedBox(height: 3),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.add, color: AppColors.brass),
            ],
          ),
        ),
      ),
    );
  }
}
