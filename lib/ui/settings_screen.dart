import 'package:flutter/material.dart';

import '../services/platform_service.dart';
import '../state/rig_controller.dart';
import 'theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});
  final RigController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<AudioDevice> _devices = const [];
  Map<String, dynamic> _info = const {};

  RigController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final d = await c.platform.listDevices();
    final i = await c.platform.deviceInfo();
    if (mounted)
      setState(() {
        _devices = d;
        _info = i;
      });
  }

  Widget _deviceDropdown({
    required String label,
    required bool input,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    final list = _devices.where((d) => input ? d.isInput : d.isOutput).toList();
    final ids = {0, ...list.map((d) => d.id)};
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: ids.contains(value) ? value : 0,
          items: [
            const DropdownMenuItem(value: 0, child: Text('Padrão do sistema')),
            for (final d in list)
              DropdownMenuItem(
                value: d.id,
                child: Text(
                  '${d.name}${d.isBluetooth ? ' (Bluetooth: alta latência)' : ''}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.settings;
        final hasBtOut = _devices.any((d) => d.isOutput && d.isBluetooth);
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const _Title('Níveis'),
              _SliderRow(
                label: 'Ganho de entrada',
                value: s.inputGainDb,
                min: -20,
                max: 30,
                display: '${s.inputGainDb >= 0 ? '+' : ''}${s.inputGainDb.toStringAsFixed(1)} dB',
                onChanged: c.setInputGain,
              ),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Ajuste para o medidor IN ficar no verde/amarelo ao palhetar forte, sem acender o LED vermelho.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
              _SliderRow(
                label: 'Volume de saída',
                value: s.outputGainDb,
                min: -30,
                max: 12,
                display: '${s.outputGainDb >= 0 ? '+' : ''}${s.outputGainDb.toStringAsFixed(1)} dB',
                onChanged: c.setOutputGain,
              ),
              _SliderRow(
                label: 'Volume do looper',
                value: s.looperLevel,
                min: 0,
                max: 1.5,
                display: '${(s.looperLevel * 100).round()}%',
                onChanged: c.setLooperLevel,
              ),
              const _Title('Dispositivos de áudio'),
              _deviceDropdown(
                label: 'Entrada',
                input: true,
                value: s.inputDevice,
                onChanged: (v) => c.setDevices(input: v),
              ),
              const SizedBox(height: 12),
              _deviceDropdown(
                label: 'Saída',
                input: false,
                value: s.outputDevice,
                onChanged: (v) => c.setDevices(output: v),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Atualizar lista'),
                ),
              ),
              if (hasBtOut)
                const _Tip(
                  icon: Icons.bluetooth_disabled,
                  text:
                      'Fones Bluetooth adicionam 150–300 ms de atraso. Para tocar, use fone com fio ou interface USB.',
                ),
              const _Tip(
                icon: Icons.cable,
                text:
                    'Conecte a guitarra com uma interface USB (ex.: tipo iRig/USB-C) ou um adaptador de 3,5 mm (TRRS). '
                    'Use fones de ouvido: com o microfone e o alto-falante do celular ocorre microfonia.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Manter tela ligada com o áudio ativo'),
                value: s.keepScreenOn,
                onChanged: c.setKeepScreenOn,
              ),
              const _Title('Desempenho'),
              ValueListenableBuilder<EngineStatus>(
                valueListenable: c.status,
                builder: (context, st, _) {
                  final a = st.stats;
                  if (!c.audioOn) {
                    return const Text(
                      'Ligue o áudio para ver latência e buffer.',
                      style: TextStyle(color: AppColors.muted),
                    );
                  }
                  return Column(
                    children: [
                      _Info('Taxa de amostragem', '${a.sampleRate} Hz'),
                      _Info('Buffer de saída', '${a.bufferFrames} amostras (burst ${a.burstFrames})'),
                      _Info('Latência estimada', '≈ ${a.latencyMs.toStringAsFixed(1)} ms'),
                      _Info('Modo exclusivo (MMAP)', a.exclusive ? 'sim' : 'não (compartilhado)'),
                      _Info('Falhas (xruns)', '${a.xruns}'),
                    ],
                  );
                },
              ),
              if (_info.isNotEmpty) ...[
                _Info('Aparelho', '${_info['model']} · Android API ${_info['sdk']}'),
                _Info('Áudio de baixa latência', _info['lowLatency'] == true ? 'suportado' : 'não declarado'),
                _Info('Áudio profissional', _info['proAudio'] == true ? 'suportado' : 'não declarado'),
              ],
              const SizedBox(height: 8),
              const Text(
                'Quando há falhas, o app aumenta o buffer automaticamente. A latência real depende do aparelho; '
                'celulares com "áudio profissional" costumam ficar abaixo de 20 ms.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Text(text, style: AppText.section),
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label)),
        Expanded(
          child: Slider(min: min, max: max, value: value.clamp(min, max), onChanged: onChanged),
        ),
        SizedBox(width: 70, child: Text(display, textAlign: TextAlign.right)),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.muted)),
        ),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    ),
  );
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(10)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}
