import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/defaults.dart';
import '../logic/dates.dart';
import '../models/models.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Add or edit one subject. Pass null to create.
///
/// Only the name is required. Faculty and room are optional because most people
/// never care, and a form that demands them is a form that doesn't get filled
/// in. There is deliberately no course-code field — nobody looks up their own
/// attendance by course code.
Future<void> showSubjectEditor(BuildContext context, Subject? existing) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SubjectEditorSheet(existing: existing),
  );
}

class _SubjectEditorSheet extends ConsumerStatefulWidget {
  final Subject? existing;
  const _SubjectEditorSheet({required this.existing});

  @override
  ConsumerState<_SubjectEditorSheet> createState() =>
      _SubjectEditorSheetState();
}

class _SubjectEditorSheetState extends ConsumerState<_SubjectEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _faculty = TextEditingController(
    text: widget.existing?.faculty ?? '',
  );
  late final _room = TextEditingController(text: widget.existing?.room ?? '');
  late int _color =
      widget.existing?.color ??
      nextSubjectColor(ref.read(appProvider).subjects.map((s) => s.color));

  bool _showOptional = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _showOptional =
        (widget.existing?.faculty ?? '').isNotEmpty ||
        (widget.existing?.room ?? '').isNotEmpty;
  }

  @override
  void dispose() {
    _name.dispose();
    _faculty.dispose();
    _room.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit subject' : 'New subject',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: !isEdit,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Subject name',
                hintText: 'e.g. Operating Systems Lab',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 6),
            Text(
              'Track labs as their own subject — most colleges enforce a '
              'separate 75% on them.',
              style: TextStyle(
                fontSize: 12,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'COLOUR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in subjectPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: _color == c
                            ? Border.all(
                                color: context.colors.onSurface,
                                width: 3,
                              )
                            : null,
                      ),
                      child: _color == c
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_showOptional)
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add teacher or room (optional)'),
                onPressed: () => setState(() => _showOptional = true),
              )
            else ...[
              TextField(
                controller: _faculty,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Teacher (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _room,
                decoration: const InputDecoration(
                  labelText: 'Room (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (isEdit)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: context.risk.danger,
                    ),
                    onPressed: _confirmDelete,
                  ),
                const Spacer(),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name');
      return;
    }

    final faculty = _faculty.text.trim();
    final room = _room.text.trim();

    ref
        .read(appProvider.notifier)
        .upsertSubject(
          Subject(
            id: widget.existing?.id ?? newId('sub-'),
            name: name,
            color: _color,
            faculty: faculty.isEmpty ? null : faculty,
            room: room.isEmpty ? null : room,
            targetPercent:
                widget.existing?.targetPercent ??
                ref.read(appProvider).term?.defaultTarget ??
                0.75,
          ),
        );
    Navigator.of(context).pop();
  }

  /// Deleting cascades to slots and records, so the dialog states exactly what
  /// is about to disappear rather than asking "are you sure?" in the abstract.
  Future<void> _confirmDelete() async {
    final state = ref.read(appProvider);
    final subject = widget.existing!;
    final slots = state.slotsForSubject(subject.id).length;
    final records = state.recordsForSubject(subject.id).length;

    final parts = [
      if (slots > 0) '$slots timetable ${slots == 1 ? 'entry' : 'entries'}',
      if (records > 0)
        '$records attendance ${records == 1 ? 'record' : 'records'}',
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${subject.name}?'),
        content: Text(
          parts.isEmpty
              ? 'Nothing else is attached to it.'
              : 'This also deletes ${parts.join(' and ')}. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.risk.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    ref.read(appProvider.notifier).deleteSubject(subject.id);
    if (mounted) Navigator.of(context).pop();
  }
}
