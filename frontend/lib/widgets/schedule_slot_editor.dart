import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fitxem/models/schedule_slot.dart';
import 'package:fitxem/theme/app_theme.dart';

class ScheduleSlotEditor extends StatelessWidget {
  const ScheduleSlotEditor({
    super.key,
    required this.slots,
    required this.onChanged,
  });

  final List<ScheduleSlot> slots;
  final ValueChanged<List<ScheduleSlot>> onChanged;

  static List<ScheduleSlot> defaultWeekdaySlots({
    String start = '09:00',
    String end = '17:00',
  }) {
    return List.generate(
      5,
      (i) => ScheduleSlot(dayOfWeek: i, startTime: start, endTime: end),
    );
  }

  List<int> _indicesForDay(int day) {
    final indices = <int>[];
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].dayOfWeek == day) indices.add(i);
    }
    return indices;
  }

  List<ScheduleSlot> _sorted(List<ScheduleSlot> list) {
    final copy = List<ScheduleSlot>.from(list);
    copy.sort((a, b) {
      final dayCmp = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (dayCmp != 0) return dayCmp;
      return a.startTime.compareTo(b.startTime);
    });
    return copy;
  }

  void _toggleDay(int day, bool enabled) {
    if (!enabled) {
      onChanged(slots.where((s) => s.dayOfWeek != day).toList());
      return;
    }
    onChanged(_sorted([
      ...slots,
      ScheduleSlot(dayOfWeek: day, startTime: '09:00', endTime: '17:00'),
    ]));
  }

  void _addSlot(int day) {
    final daySlots =
        slots.where((s) => s.dayOfWeek == day).toList(growable: false);
    var start = '09:00';
    var end = '17:00';
    if (daySlots.isNotEmpty) {
      start = _nextStartAfter(daySlots.last.endTime);
      end = _defaultEnd(start);
    }
    onChanged(_sorted([
      ...slots,
      ScheduleSlot(dayOfWeek: day, startTime: start, endTime: end),
    ]));
  }

  void _removeSlot(int index) {
    final next = List<ScheduleSlot>.from(slots)..removeAt(index);
    onChanged(next);
  }

  void _updateSlot(int index, ScheduleSlot slot) {
    final next = List<ScheduleSlot>.from(slots);
    next[index] = slot;
    onChanged(_sorted(next));
  }

  String _nextStartAfter(String endTime) {
    final parts = endTime.split(':');
    var hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    hour = (hour + 2).clamp(0, 23);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _defaultEnd(String startTime) {
    final parts = startTime.split(':');
    var hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    hour = (hour + 4).clamp(0, 23);
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTime(
    BuildContext context,
    int index,
    bool isStart,
  ) async {
    final slot = slots[index];
    final parts = (isStart ? slot.startTime : slot.endTime).split(':');
    final initial = TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _updateSlot(
      index,
      isStart
          ? slot.copyWith(startTime: formatted)
          : slot.copyWith(endTime: formatted),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var day = 0; day < 7; day++) ...[
          if (day > 0) const SizedBox(height: 10),
          _DayCard(
            day: day,
            label: scheduleDayFullLabels[day],
            enabled: _indicesForDay(day).isNotEmpty,
            slotIndices: _indicesForDay(day),
            slots: slots,
            errorText: validateDaySlots(
              slots.where((s) => s.dayOfWeek == day).toList(),
            ),
            onToggle: (v) => _toggleDay(day, v),
            onAddSlot: () => _addSlot(day),
            onRemoveSlot: _removeSlot,
            onPickStart: (index) => _pickTime(context, index, true),
            onPickEnd: (index) => _pickTime(context, index, false),
          ),
        ],
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.label,
    required this.enabled,
    required this.slotIndices,
    required this.slots,
    required this.errorText,
    required this.onToggle,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onPickStart,
    required this.onPickEnd,
  });

  final int day;
  final String label;
  final bool enabled;
  final List<int> slotIndices;
  final List<ScheduleSlot> slots;
  final String? errorText;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAddSlot;
  final void Function(int index) onRemoveSlot;
  final void Function(int index) onPickStart;
  final void Function(int index) onPickEnd;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: enabled ? AppTheme.surface : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: hasError
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : enabled
                  ? AppTheme.border.withValues(alpha: 0.9)
                  : AppTheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 14, 12, enabled ? 4 : 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: AppTheme.rowTitle(context)),
                ),
                Switch.adaptive(
                  value: enabled,
                  onChanged: onToggle,
                  activeTrackColor: AppTheme.textPrimary,
                ),
              ],
            ),
          ),
          if (enabled) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < slotIndices.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _SlotRow(
                      slot: slots[slotIndices[i]],
                      canRemove: slotIndices.length > 1,
                      onPickStart: () => onPickStart(slotIndices[i]),
                      onPickEnd: () => onPickEnd(slotIndices[i]),
                      onRemove: () => onRemoveSlot(slotIndices[i]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _AddSlotButton(onTap: onAddSlot),
                  if (hasError) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorText!,
                      style: AppTheme.rowMeta(context).copyWith(
                        fontSize: 12,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.canRemove,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onRemove,
  });

  final ScheduleSlot slot;
  final bool canRemove;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Desde', style: AppTheme.rowMeta(context)),
        const SizedBox(width: 8),
        Flexible(child: _TimeChip(label: slot.startTime, onTap: onPickStart)),
        const SizedBox(width: 10),
        Text('Hasta', style: AppTheme.rowMeta(context)),
        const SizedBox(width: 8),
        Flexible(child: _TimeChip(label: slot.endTime, onTap: onPickEnd)),
        if (canRemove)
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              CupertinoIcons.xmark,
              size: 16,
              color: AppTheme.textSecondary,
            ),
            style: IconButton.styleFrom(
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: AppTheme.bordered(radius: AppTheme.radiusSm),
          child: Text(
            label,
            style: AppTheme.rowTitle(context).copyWith(fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class _AddSlotButton extends StatelessWidget {
  const _AddSlotButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.plus,
                size: 16,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Añadir tramo',
                style: AppTheme.rowMeta(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
