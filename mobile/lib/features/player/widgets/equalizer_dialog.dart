import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/equalizer_provider.dart';

class EqualizerDialog extends ConsumerWidget {
  const EqualizerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);

    final minLevel = eqState.bandRange.isNotEmpty ? eqState.bandRange[0] : -1500;
    final maxLevel = eqState.bandRange.length > 1 ? eqState.bandRange[1] : 1500;

    return AlertDialog(
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.equalizer, color: AppTheme.neonGreen),
              SizedBox(width: 8),
              Text(
                'Equalizer (5-Band)',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
              ),
            ],
          ),
          Switch(
            value: eqState.isEnabled,
            activeColor: AppTheme.neonGreen,
            onChanged: (val) => eqNotifier.toggleEnabled(val),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preset Dropdown
              if (eqState.presets.isNotEmpty) ...[
                const Text(
                  'Cài đặt sẵn (Presets)',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppTheme.surfaceDark,
                      value: eqState.currentPreset ?? eqState.presets.first,
                      items: eqState.presets.map((preset) {
                        return DropdownMenuItem<String>(
                          value: preset,
                          child: Text(
                            preset,
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                        );
                      }).toList(),
                      onChanged: eqState.isEnabled
                          ? (preset) {
                              if (preset != null) eqNotifier.setPreset(preset);
                            }
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 5-Band Vertical Sliders Row
              const Text(
                'Tần số âm thanh',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(eqState.bandFrequencies.length, (index) {
                    final freqHz = (eqState.bandFrequencies[index] / 1000).round();
                    final freqLabel = freqHz >= 1000 ? '${(freqHz / 1000).toStringAsFixed(1)}k' : '$freqHz';
                    final currentVal = index < eqState.bandLevels.length
                        ? eqState.bandLevels[index]
                        : 0;

                    return Column(
                      children: [
                        Text(
                          '${(currentVal / 100).toStringAsFixed(0)}dB',
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                        ),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Slider(
                              value: currentVal.toDouble().clamp(minLevel.toDouble(), maxLevel.toDouble()),
                              min: minLevel.toDouble(),
                              max: maxLevel.toDouble(),
                              activeColor: AppTheme.neonGreen,
                              inactiveColor: AppTheme.surfaceLight,
                              onChanged: eqState.isEnabled
                                  ? (val) => eqNotifier.setBandLevel(index, val.toInt())
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          freqLabel,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Bass Boost
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bass Boost',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${(eqState.bassBoost / 10).round()}%',
                    style: const TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Slider(
                value: eqState.bassBoost.toDouble(),
                min: 0,
                max: 1000,
                activeColor: AppTheme.neonGreen,
                inactiveColor: AppTheme.surfaceLight,
                onChanged: eqState.isEnabled
                    ? (val) => eqNotifier.setBassBoost(val.toInt())
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng', style: TextStyle(color: AppTheme.neonGreen)),
        ),
      ],
    );
  }
}
