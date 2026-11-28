import 'package:flutter/material.dart' hide Text;
import 'package:employer_kariger_app/core/api/api_exception.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/app_scope.dart';
import '../../core/theme.dart';
import '../../widgets/localized_text.dart';

class AiCallSettingsScreen extends StatefulWidget {
  const AiCallSettingsScreen({super.key});

  @override
  State<AiCallSettingsScreen> createState() => _AiCallSettingsScreenState();
}

class _AiCallSettingsScreenState extends State<AiCallSettingsScreen> {
  bool loading = true, saving = false, callsOn = true;
  String? error;
  Map<String, dynamic> options = const {};
  Map<String, dynamic> values = {
    'trigger': 'shortlist',
    'delay_minutes': 0,
    'window_start': null,
    'window_end': null,
    'days': [1, 2, 3, 4, 5, 6, 7],
    'who': 'all',
    'min_score': 60,
    'daily_limit': 0,
    'reminder_call': true,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading) _load();
  }

  Future<void> _load() async {
    try {
      final response = await AppScope.of(context).api.aiCallSettings();
      if (!mounted) return;
      final setting = response['settings'];
      setState(() {
        if (setting is Map) {
          values = {...values, ...Map<String, dynamic>.from(setting)};
        }
        options = response['options'] is Map
            ? Map<String, dynamic>.from(response['options'])
            : const {};
        callsOn = response['calls_on'] != false;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _items(String key) =>
      (options[key] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  void _set(String key, dynamic value) => setState(() => values[key] = value);

  Future<void> _time(String key) async {
    final current = values[key]?.toString().split(':');
    final initial = current?.length == 2
        ? TimeOfDay(
            hour: int.tryParse(current![0]) ?? 10,
            minute: int.tryParse(current[1]) ?? 0,
          )
        : const TimeOfDay(hour: 10, minute: 0);
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected != null) {
      _set(
        key,
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  Future<void> _save() async {
    final days = (values['days'] as List? ?? const []);
    if (days.isEmpty) return _notice('Choose at least one calling day.');
    if (_minute(values['window_start']) != null &&
        _minute(values['window_end']) != null &&
        _minute(values['window_start'])! >= _minute(values['window_end'])!) {
      return _notice('End time must be after start time.');
    }
    setState(() => saving = true);
    try {
      final response = await AppScope.of(
        context,
      ).api.updateAiCallSettings(values);
      if (!mounted) return;
      final setting = response['settings'];
      if (setting is Map) {
        setState(
          () => values = {...values, ...Map<String, dynamic>.from(setting)},
        );
      }
      _notice('${response['message'] ?? 'AI call settings saved'}');
    } catch (e) {
      _notice(errorText(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  int? _minute(Object? value) {
    final p = '$value'.split(':');
    return p.length == 2
        ? (int.tryParse(p[0]) ?? -1) * 60 + (int.tryParse(p[1]) ?? -1)
        : null;
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('AI call settings')),
        body: Center(
          child: OutlinedButton(onPressed: _load, child: const Text('Retry')),
        ),
      );
    }
    final window = options['window'] as Map? ?? const {};
    // The server names the zone "Asia/Kolkata"; employers know it as IST.
    final rawZone = '${window['timezone'] ?? 'IST'}';
    final zone = rawZone == 'Asia/Kolkata' ? 'IST' : rawZone;
    return Scaffold(
      appBar: AppBar(title: const Text('AI call settings')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.save),
            label: Text(saving ? 'Saving…' : 'Save settings'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          _Hero(callsOn: callsOn),
          _Section(
            title: 'When to call',
            child: _ChoiceList(
              items: _items('triggers'),
              selected: '${values['trigger']}',
              onChanged: (v) => _set('trigger', v),
            ),
          ),
          _Section(
            title: 'Call delay',
            child: _ChoiceList(
              items: _items('delays'),
              selected: '${values['delay_minutes']}',
              onChanged: (v) => _set('delay_minutes', int.tryParse(v) ?? 0),
            ),
          ),
          _Section(
            title: 'Who gets an automatic call',
            child: Column(
              children: [
                _ChoiceList(
                  items: _items('who'),
                  selected: '${values['who']}',
                  onChanged: (v) => _set('who', v),
                ),
                if (values['who'] == 'score')
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Minimum AI match score',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: TextFormField(
                            initialValue: '${values['min_score']}',
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            onChanged: (v) => _set(
                              'min_score',
                              (int.tryParse(v) ?? 60).clamp(0, 100),
                            ),
                            decoration: const InputDecoration(suffixText: '%'),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          _Section(
            title: 'Calling hours',
            subtitle:
                'Optional. Keep platform hours, or set a narrower window (${window['start'] ?? '—'}–${window['end'] ?? '—'} $zone).',
            child: Row(
              children: [
                Expanded(
                  child: _TimeTile(
                    label: 'Start',
                    // Unset means the platform hours: show that time, not
                    // the bare word "Platform".
                    value:
                        values['window_start']?.toString() ??
                        '${window['start'] ?? '—'} (default)',
                    onTap: () => _time('window_start'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeTile(
                    label: 'End',
                    value:
                        values['window_end']?.toString() ??
                        '${window['end'] ?? '—'} (default)',
                    onTap: () => _time('window_end'),
                  ),
                ),
              ],
            ),
          ),
          if (values['window_start'] != null || values['window_end'] != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() {
                  values['window_start'] = null;
                  values['window_end'] = null;
                }),
                child: const Text('Use platform hours'),
              ),
            ),
          _Section(
            title: 'Calling days',
            subtitle:
                'Calls due on another day move to your next selected day.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _items('days').map((day) {
                final value = day['value'];
                final selected = (values['days'] as List).contains(value);
                return FilterChip(
                  label: Text('${day['label']}'),
                  selected: selected,
                  onSelected: (_) {
                    final next = List<dynamic>.from(values['days'] as List);
                    selected ? next.remove(value) : next.add(value);
                    _set('days', next);
                  },
                );
              }).toList(),
            ),
          ),
          _Section(
            title: 'Daily call cap',
            subtitle: 'Automatic calls only. Manual calls always ring now.',
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Calls per job per day',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(
                  width: 86,
                  child: TextFormField(
                    initialValue: '${values['daily_limit']}',
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (v) => _set('daily_limit', int.tryParse(v) ?? 0),
                    decoration: const InputDecoration(hintText: '0'),
                  ),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Interview reminder',
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('AI reminder call'),
              subtitle: const Text(
                'Call the karigar on the morning of a booked interview.',
              ),
              value: values['reminder_call'] == true,
              onChanged: (v) => _set('reminder_call', v),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.callsOn});
  final bool callsOn;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: callsOn
          ? AppColors.brand50
          : Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(
          callsOn ? LucideIcons.botMessageSquare : LucideIcons.circleAlert,
          color: AppColors.brandDark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            callsOn
                ? 'Set the timing for automatic AI screening calls across your team.'
                : 'AI calls are currently switched off on the platform. Your preferences will still be saved.',
            style: const TextStyle(height: 1.35, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  // A Material, not a coloured Container: the radio and switch tiles paint
  // their tap ink on it, which a Container's colour would hide.
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 10),
                child: Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ),
  );
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.items,
    required this.selected,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> items;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  // One RadioGroup holds the choice for all the tiles (per-tile groupValue
  // and onChanged are deprecated).
  Widget build(BuildContext context) => RadioGroup<String>(
    groupValue: selected,
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
    child: Column(
      children: items.map((item) {
        final value = '${item['value']}';
        return RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: value,
          title: Text(
            '${item['label']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: item['description']?.toString().isNotEmpty == true
              ? Text(
                  '${item['description']}',
                  style: const TextStyle(fontSize: 12),
                )
              : null,
        );
      }).toList(),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label, value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
