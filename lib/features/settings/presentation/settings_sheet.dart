import 'package:benkyo/app/theme/tokens.dart';
import 'package:benkyo/core/widgets/glass_sheet.dart';
import 'package:benkyo/features/onboarding/presentation/onboarding_providers.dart';
import 'package:benkyo/features/timer/domain/pomodoro.dart';
import 'package:benkyo/features/timer/presentation/timer_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _sheet = SheetToggle((_) => const _SettingsSheet());

/// ⌘, : open Settings, or close it if it's open.
void toggleSettingsSheet(BuildContext context) => _sheet.toggle(context);

class _SettingsSheet extends ConsumerWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final s = ref.watch(timerSettingsProvider);
    final settings = ref.read(timerSettingsProvider.notifier);
    void set(TimerSettings next) => settings.update(next);
    Duration m(int minutes) => Duration(minutes: minutes);

    return GlassSheet(
      width: 520,
      height: 470,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Settings', style: text.headlineSmall),
              const Spacer(),
              IconButton(
                tooltip: 'Close (Esc)',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: Tokens.s12),
          const _Section('TIMER'),
          _Stepper(
            label: 'Focus',
            value: s.focus.inMinutes,
            unit: 'min',
            min: 5,
            max: 120,
            step: 5,
            onChanged: (v) => set(s.copyWith(focus: m(v))),
          ),
          _Stepper(
            label: 'Short break',
            value: s.shortBreak.inMinutes,
            unit: 'min',
            min: 1,
            max: 30,
            step: 1,
            onChanged: (v) => set(s.copyWith(shortBreak: m(v))),
          ),
          _Stepper(
            label: 'Long break',
            value: s.longBreak.inMinutes,
            unit: 'min',
            min: 5,
            max: 60,
            step: 5,
            onChanged: (v) => set(s.copyWith(longBreak: m(v))),
          ),
          _Stepper(
            label: 'Long break after',
            value: s.sessionsBeforeLongBreak,
            unit: 'sessions',
            min: 2,
            max: 8,
            step: 1,
            onChanged: (v) => set(s.copyWith(sessionsBeforeLongBreak: v)),
          ),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Start the next phase automatically',
                style: text.bodyMedium,
              ),
              value: s.autoStartNext,
              onChanged: (on) => set(s.copyWith(autoStartNext: on)),
            ),
          ),
          const Spacer(),
          const _Section('GENERAL'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Tokens.text),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(onboardingProvider.notifier).replay();
              },
              child: const Text('Show Welcome Tour Again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: Tokens.textSecondary),
    ),
  );
}

/// "Focus      25 min  − +", like a macOS stepper row.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String unit;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(
            '$value $unit',
            style: text.bodyMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: Tokens.s8),
          IconButton(
            tooltip: 'Less $label',
            icon: const Icon(Icons.remove, size: 16),
            onPressed: value - step < min
                ? null
                : () => onChanged(value - step),
          ),
          IconButton(
            tooltip: 'More $label',
            icon: const Icon(Icons.add, size: 16),
            onPressed: value + step > max
                ? null
                : () => onChanged(value + step),
          ),
        ],
      ),
    );
  }
}
