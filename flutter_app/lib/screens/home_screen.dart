import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/task_service.dart';

enum TaskFilter { all, active, completed }

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({super.key});

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  final TaskService _service = TaskService();
  List<Task> _tasks = const [];
  TaskFilter _filter = TaskFilter.all;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int get _completedCount => _tasks.where((task) => task.completed).length;
  int get _activeCount => _tasks.length - _completedCount;
  double get _progress => _tasks.isEmpty ? 0 : _completedCount / _tasks.length;

  List<Task> get _visibleTasks {
    switch (_filter) {
      case TaskFilter.active:
        return _tasks.where((task) => !task.completed).toList();
      case TaskFilter.completed:
        return _tasks.where((task) => task.completed).toList();
      case TaskFilter.all:
        return _tasks;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tasks = await _service.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openEditor({Task? task}) async {
    final result = await showDialog<_TaskInput>(
      context: context,
      builder: (context) => _TaskEditorDialog(task: task),
    );
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      if (task == null) {
        await _service.createTask(title: result.title, description: result.description);
      } else {
        await _service.updateTask(task.id, title: result.title, description: result.description);
      }
      await _loadTasks(showLoading: false);
      if (mounted) _showMessage(task == null ? 'Task added successfully.' : 'Task updated.');
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleTask(Task task, bool completed) async {
    setState(() => _saving = true);
    try {
      await _service.updateTask(task.id, completed: completed);
      await _loadTasks(showLoading: false);
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('“${task.title}” will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await _service.deleteTask(task.id);
      await _loadTasks(showLoading: false);
      if (mounted) _showMessage('Task deleted.');
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFB42318) : const Color(0xFF202B50),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final visibleTasks = _visibleTasks;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _TopBar(onRefresh: () => _loadTasks(), saving: _saving),
                const SizedBox(height: 34),
                LayoutBuilder(builder: (context, constraints) {
                  final compact = constraints.maxWidth < 530;
                  final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Make room for\nwhat matters.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -1.1, color: const Color(0xFF202744))),
                    const SizedBox(height: 10),
                    const Text('Small steps add up. Pick one thing and get started.', style: TextStyle(color: Color(0xFF727A90), height: 1.5)),
                  ]);
                  final button = FilledButton.icon(
                    onPressed: _saving ? null : () => _openEditor(),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Add task'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );
                  return compact
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, const SizedBox(height: 18), button])
                    : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: title), button]);
                }),
                const SizedBox(height: 26),
                _ProgressCard(total: _tasks.length, completed: _completedCount, progress: _progress),
                const SizedBox(height: 18),
                LayoutBuilder(builder: (context, constraints) {
                  final gap = constraints.maxWidth < 500 ? 8.0 : 12.0;
                  return Row(children: [
                    Expanded(child: _StatCard(label: 'All tasks', value: _tasks.length, icon: Icons.grid_view_rounded, tint: const Color(0xFFE8EDFF), iconColor: const Color(0xFF3858D6))),
                    SizedBox(width: gap),
                    Expanded(child: _StatCard(label: 'In progress', value: _activeCount, icon: Icons.bolt_rounded, tint: const Color(0xFFFFF1D6), iconColor: const Color(0xFFB7791F))),
                    SizedBox(width: gap),
                    Expanded(child: _StatCard(label: 'Completed', value: _completedCount, icon: Icons.check_circle_outline_rounded, tint: const Color(0xFFDDF7EB), iconColor: const Color(0xFF18845B))),
                  ]);
                }),
                const SizedBox(height: 30),
                Row(children: [
                  Expanded(child: Text('Your tasks', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: const Color(0xFF202744)))),
                  if (_saving) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _FilterChip(label: 'All', count: _tasks.length, selected: _filter == TaskFilter.all, onTap: () => setState(() => _filter = TaskFilter.all)),
                  _FilterChip(label: 'In progress', count: _activeCount, selected: _filter == TaskFilter.active, onTap: () => setState(() => _filter = TaskFilter.active)),
                  _FilterChip(label: 'Completed', count: _completedCount, selected: _filter == TaskFilter.completed, onTap: () => setState(() => _filter = TaskFilter.completed)),
                ]),
                const SizedBox(height: 14),
                if (_loading) const _LoadingState()
                else if (_error != null) _ErrorState(message: _error!, onRetry: () => _loadTasks())
                else if (visibleTasks.isEmpty) _EmptyState(
                  isFiltered: _tasks.isNotEmpty,
                  onAdd: () => _openEditor(),
                  onShowAll: () => setState(() => _filter = TaskFilter.all),
                )
                else ...visibleTasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(
                    task: task, disabled: _saving,
                    onToggle: (completed) => _toggleTask(task, completed),
                    onEdit: () => _openEditor(task: task),
                    onDelete: () => _deleteTask(task),
                  ),
                )),
                const SizedBox(height: 20),
                const Center(child: Text('TASKFLOW  •  ONE STEP AT A TIME', style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: Color(0xFF9AA1B3)))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onRefresh, required this.saving});
  final VoidCallback onRefresh;
  final bool saving;

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF3858D6), borderRadius: BorderRadius.circular(13)),
      child: const Icon(Icons.checklist_rounded, color: Colors.white)),
    const SizedBox(width: 11),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('taskflow', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF252B45), letterSpacing: -0.5)),
      Text('YOUR PERSONAL WORKSPACE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8B92A5), letterSpacing: 1)),
    ]),
    const Spacer(),
    IconButton(tooltip: 'Refresh tasks', onPressed: saving ? null : onRefresh, icon: const Icon(Icons.refresh_rounded, color: Color(0xFF646D84))),
  ]);
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.total, required this.completed, required this.progress});
  final int total;
  final int completed;
  final double progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF263C96), Color(0xFF4666E8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Your progress', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.16), borderRadius: BorderRadius.circular(10)),
          child: Text(total == 0 ? 'Ready when you are' : '${(progress * 100).round()}% complete', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 18),
      ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(
        value: progress, minHeight: 7, backgroundColor: Colors.white.withOpacity(0.22), color: Colors.white)),
      const SizedBox(height: 12),
      Text('$completed of $total tasks completed', style: const TextStyle(color: Color(0xFFE4E9FF), fontSize: 12)),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.tint, required this.iconColor});
  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFEAECF3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 17)),
      const SizedBox(height: 12),
      Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1, color: Color(0xFF252B45))),
      const SizedBox(height: 5),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF80889D), fontWeight: FontWeight.w600))),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.count, required this.selected, required this.onTap});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onTap,
    avatar: null,
    label: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 7),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: selected ? Colors.white.withOpacity(0.2) : const Color(0xFFEEF0F6), borderRadius: BorderRadius.circular(7)),
        child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: selected ? Colors.white : const Color(0xFF737B91)))),
    ]),
    labelStyle: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? Colors.white : const Color(0xFF737B91), fontSize: 12),
    backgroundColor: Colors.white,
    side: BorderSide(color: selected ? const Color(0xFF3858D6) : const Color(0xFFE4E7EF)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    color: selected ? const Color(0xFF3858D6) : Colors.white,
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.disabled, required this.onToggle, required this.onEdit, required this.onDelete});
  final Task task;
  final bool disabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white, elevation: 0, margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFEAECF3))),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 1), child: Checkbox(value: task.completed, onChanged: disabled ? null : (value) { if (value != null) onToggle(value); })),
        const SizedBox(width: 3),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, style: TextStyle(fontWeight: FontWeight.w700,
              color: task.completed ? const Color(0xFF9AA0B1) : const Color(0xFF252B45),
              decoration: task.completed ? TextDecoration.lineThrough : TextDecoration.none, height: 1.35)),
            if (task.description.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(task.description, style: const TextStyle(color: Color(0xFF7A8297), fontSize: 12, height: 1.4)),
            ],
            const SizedBox(height: 9),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: task.completed ? const Color(0xFFE2F7EC) : const Color(0xFFFFF2DA), borderRadius: BorderRadius.circular(7)),
              child: Text(task.completed ? 'COMPLETED' : 'IN PROGRESS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.6,
                color: task.completed ? const Color(0xFF18845B) : const Color(0xFFA36C14)))),
          ]),
        )),
        PopupMenuButton<String>(
          tooltip: 'Task actions', enabled: !disabled,
          onSelected: (action) { if (action == 'edit') onEdit(); if (action == 'delete') onDelete(); },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
            PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, color: Color(0xFFB42318)), title: Text('Delete'))),
          ],
          icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF858CA0)),
        ),
      ]),
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      CircularProgressIndicator(), SizedBox(height: 14), Text('Loading your tasks...', style: TextStyle(color: Color(0xFF81889C))),
    ])),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFF0C8C5))),
    child: Column(children: [
      const Icon(Icons.cloud_off_rounded, color: Color(0xFFB42318), size: 30),
      const SizedBox(height: 10),
      const Text('Could not load tasks', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF252B45))),
      const SizedBox(height: 6),
      Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF81889C), fontSize: 12)),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered, required this.onAdd, required this.onShowAll});
  final bool isFiltered;
  final VoidCallback onAdd;
  final VoidCallback onShowAll;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEAECF3))),
    child: Column(children: [
      Container(width: 58, height: 58, decoration: const BoxDecoration(color: Color(0xFFE8EDFF), shape: BoxShape.circle),
        child: const Icon(Icons.edit_note_rounded, color: Color(0xFF3858D6), size: 29)),
      const SizedBox(height: 14),
      Text(isFiltered ? 'Nothing in this view' : 'A clean slate', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF252B45))),
      const SizedBox(height: 7),
      Text(isFiltered ? 'Try another filter to find your tasks.' : 'Add your first task and turn an idea into action.',
        textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF81889C), fontSize: 12, height: 1.5)),
      const SizedBox(height: 16),
      if (isFiltered) TextButton(onPressed: onShowAll, child: const Text('Show all tasks'))
      else FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add_rounded), label: const Text('Create a task')),
    ]),
  );
}

class _TaskInput {
  const _TaskInput({required this.title, required this.description});
  final String title;
  final String description;
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({this.task});
  final Task? task;
  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_TaskInput(title: _titleController.text.trim(), description: _descriptionController.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? 'Create a task' : 'Edit task', style: const TextStyle(fontWeight: FontWeight.w800)),
    content: SizedBox(width: 420, child: Form(
      key: _formKey,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: _titleController, autofocus: true, maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Task title', hintText: 'e.g. Practise Flutter widgets'),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return 'Please enter a task title.';
            if (value.trim().length > 120) return 'Use 120 characters or fewer.';
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController, maxLength: 500, maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Description (optional)', hintText: 'Add a little context'),
          validator: (value) => (value?.trim().length ?? 0) > 500 ? 'Use 500 characters or fewer.' : null,
        ),
      ]),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: Text(widget.task == null ? 'Create task' : 'Save changes')),
    ],
  );
}
