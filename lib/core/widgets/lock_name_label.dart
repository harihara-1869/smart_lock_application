import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartlock_application/core/providers/nfc_providers.dart';
import 'package:smartlock_application/features/session/trusted_locks_store.dart';

/// Tappable display of a lock's name (with the lock ID as the fallback).
///
/// Loads the user-chosen name from [TrustedLocksStore] on first build; on tap
/// it opens an [AlertDialog] that lets the user rename the lock. Renaming
/// while [enabled] is `false` (e.g. mid-actuation) is a no-op.
class LockNameLabel extends ConsumerStatefulWidget {
  final String lockId;
  final TextStyle? style;
  final bool enabled;

  /// Visual variant. The My Keys list uses a denser card style; the actuate
  /// screen uses a centered title style.
  final LockNameLabelVariant variant;

  const LockNameLabel({
    super.key,
    required this.lockId,
    this.style,
    this.enabled = true,
    this.variant = LockNameLabelVariant.title,
  });

  @override
  ConsumerState<LockNameLabel> createState() => _LockNameLabelState();
}

enum LockNameLabelVariant { title, card }

class _LockNameLabelState extends ConsumerState<LockNameLabel> {
  String? _name;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LockNameLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lockId != widget.lockId) {
      _name = null;
      _load();
    }
  }

  Future<void> _load() async {
    final name = await ref.read(trustedLocksStoreProvider).getLockName(widget.lockId);
    if (!mounted) return;
    setState(() => _name = name);
  }

  Future<void> _editName() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameLockDialog(
        lockId: widget.lockId,
        currentName: _name,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _name = result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasName = (_name ?? '').isNotEmpty;
    final label = hasName ? _name! : widget.lockId;

    final defaultStyle = widget.variant == LockNameLabelVariant.title
        ? theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )
        : TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          );

    final textStyle = widget.style ?? defaultStyle;
    final isInteractive = widget.enabled;

    return InkWell(
      onTap: isInteractive ? _editName : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: widget.variant == LockNameLabelVariant.title
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                label,
                style: textStyle,
                textAlign: widget.variant == LockNameLabelVariant.title
                    ? TextAlign.center
                    : TextAlign.start,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isInteractive) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.edit,
                size: widget.variant == LockNameLabelVariant.title ? 18 : 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modal dialog for renaming a lock. Returns the new (trimmed, non-empty)
/// name on confirm, or `null` if dismissed / unchanged.
class _RenameLockDialog extends ConsumerStatefulWidget {
  final String lockId;
  final String? currentName;

  const _RenameLockDialog({required this.lockId, required this.currentName});

  @override
  ConsumerState<_RenameLockDialog> createState() => _RenameLockDialogState();
}

class _RenameLockDialogState extends ConsumerState<_RenameLockDialog> {
  late final TextEditingController _controller;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _controller.text;
    final trimmed = raw.trim();

    if (trimmed.isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }
    if (trimmed.length > TrustedLocksStore.maxNameLength) {
      setState(() => _error =
          'Name must be at most ${TrustedLocksStore.maxNameLength} characters');
      return;
    }
    if (trimmed == (widget.currentName ?? '').trim()) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(trustedLocksStoreProvider).setLockName(widget.lockId, trimmed);
      if (!mounted) return;
      Navigator.of(context).pop(trimmed);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save name. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename Lock'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: TrustedLocksStore.maxNameLength,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'Name',
          hintText: widget.lockId,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
