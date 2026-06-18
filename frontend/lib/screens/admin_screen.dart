import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/models/incident_request.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/request_labels.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _tab = 0;
  List<dynamic> _employees = [];
  List<IncidentRequest> _incidents = [];
  List<AbsenceRequest> _absences = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!ref.read(authProvider).isAdmin) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _error = null;
        _loading = true;
      });
    }

    try {
      final api = ref.read(apiClientProvider);
      final employees = await api.listEmployees();
      final incidents = await api.listCorrections();
      final absences = await api.listAbsences();
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _incidents = incidents;
        _absences = absences;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(String format) async {
    final to = DateTime.now().toUtc();
    final from = to.subtract(const Duration(days: 30));
    try {
      await ref.read(apiClientProvider).exportData(
            format,
            from: from.toIso8601String(),
            to: to.toIso8601String(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportación $format solicitada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!ref.watch(authProvider).isAdmin) {
      return AppPage(
        children: [
          AppPageHeader(title: l10n.admin),
          const SizedBox(height: 28),
          AppEmptyState(
            message: 'Acceso solo para administradores',
            icon: CupertinoIcons.lock,
          ),
        ],
      );
    }

    if (_loading) return const AppLoadingPage();

    return AppPage(
      children: [
        AppPageHeader(title: l10n.admin),
        const SizedBox(height: 20),
        AppSegmentedTabs(
          labels: [
            l10n.employees,
            l10n.incidents,
            l10n.ausencias,
            l10n.export,
          ],
          selectedIndex: _tab,
          onSelected: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AppErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 16),
        ],
        switch (_tab) {
          0 => _EmployeesTab(
              employees: _employees,
              onAdd: _showAddEmployee,
            ),
          1 => _IncidentsTab(
              incidents: _incidents,
              onReview: _reviewIncident,
            ),
          2 => _AbsencesTab(
              absences: _absences,
              onReview: _reviewAbsence,
            ),
          3 => _ExportTab(onExport: _export),
          _ => const SizedBox.shrink(),
        },
      ],
    );
  }

  Future<void> _reviewIncident(String id, bool approve) async {
    try {
      await ref.read(apiClientProvider).reviewCorrection(id, approve);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _reviewAbsence(String id, bool approve) async {
    try {
      await ref.read(apiClientProvider).reviewAbsence(id, approve);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  Future<void> _showAddEmployee() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEmployeeSheet(
        onCreate: (data) => ref.read(apiClientProvider).createEmployee(data),
        onSuccess: _load,
      ),
    );
  }
}

class _AddEmployeeSheet extends StatefulWidget {
  const _AddEmployeeSheet({
    required this.onCreate,
    required this.onSuccess,
  });

  final Future<void> Function(Map<String, String>) onCreate;
  final Future<void> Function() onSuccess;

  @override
  State<_AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<_AddEmployeeSheet> {
  final _nif = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nif.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onCreate({
        'nif': _nif.text.trim(),
        'full_name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
      });
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.92;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusLg),
            ),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Añadir empleado',
                          style: AppTheme.pageTitle(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          CupertinoIcons.xmark,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Text(
                    'Introduce los datos del nuevo empleado.',
                    style: AppTheme.subtitle(context),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    children: [
                      TextField(
                        controller: _nif,
                        decoration: AppTheme.inputDecoration('NIF'),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _name,
                        decoration: AppTheme.inputDecoration(l10n.ownerName),
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _email,
                        decoration: AppTheme.inputDecoration(l10n.email),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        decoration: AppTheme.inputDecoration(l10n.password),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPrimaryButton(
                        label: 'Crear empleado',
                        enabled: !_submitting,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 10),
                      AppSecondaryButton(
                        label: 'Cancelar',
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmployeesTab extends StatelessWidget {
  const _EmployeesTab({required this.employees, required this.onAdd});

  final List<dynamic> employees;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (employees.isEmpty)
          AppEmptyState(
            message: 'No hay empleados registrados',
            icon: CupertinoIcons.person_2,
          )
        else
          AppSoftCard(
            child: Column(
              children: [
                for (var i = 0; i < employees.length; i++)
                  AppSettingsRow(
                    title: (employees[i] as Map<String, dynamic>)['full_name']
                            as String? ??
                        '',
                    subtitle:
                        '${(employees[i] as Map<String, dynamic>)['nif']} · ${(employees[i] as Map<String, dynamic>)['email'] ?? ''}',
                    icon: CupertinoIcons.person,
                    showDivider: i < employees.length - 1,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        AppPrimaryButton(label: 'Añadir empleado', onTap: onAdd),
      ],
    );
  }
}

class _IncidentsTab extends StatelessWidget {
  const _IncidentsTab({
    required this.incidents,
    required this.onReview,
  });

  final List<IncidentRequest> incidents;
  final Future<void> Function(String id, bool approve) onReview;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'es');

    if (incidents.isEmpty) {
      return AppEmptyState(
        message: 'No hay incidencias pendientes',
        icon: CupertinoIcons.checkmark_seal,
      );
    }

    return AppSoftCard(
      child: Column(
        children: [
          for (var i = 0; i < incidents.length; i++)
            _IncidentAdminRow(
              incident: incidents[i],
              dateFmt: dateFmt,
              showDivider: i > 0,
              onApprove: () => onReview(incidents[i].id, true),
              onReject: () => onReview(incidents[i].id, false),
            ),
        ],
      ),
    );
  }
}

class _IncidentAdminRow extends StatelessWidget {
  const _IncidentAdminRow({
    required this.incident,
    required this.dateFmt,
    required this.showDivider,
    required this.onApprove,
    required this.onReject,
  });

  final IncidentRequest incident;
  final DateFormat dateFmt;
  final bool showDivider;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 16, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                incident.employeeName ?? 'Empleado',
                style: AppTheme.rowTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                '${incidentTypeLabel(l10n, incident.incidentType)} · ${eventTypeLabel(l10n, incident.eventType)}',
                style: AppTheme.rowMeta(context),
              ),
              const SizedBox(height: 4),
              Text(
                dateFmt.format(incident.proposedAt),
                style: AppTheme.rowMeta(context),
              ),
              if (incident.originalRecordedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${l10n.originalTime}: ${DateFormat('HH:mm').format(incident.originalRecordedAt!)} → ${DateFormat('HH:mm').format(incident.proposedAt)}',
                  style: AppTheme.rowMeta(context),
                ),
              ],
              const SizedBox(height: 6),
              Text(incident.reason, style: AppTheme.rowMeta(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: AppTheme.outlinedButtonStyle().copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(40)),
                      ),
                      child: Text(l10n.reject),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      style: AppTheme.filledButtonStyle().copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(40)),
                      ),
                      child: Text(l10n.approve),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AbsencesTab extends StatelessWidget {
  const _AbsencesTab({
    required this.absences,
    required this.onReview,
  });

  final List<AbsenceRequest> absences;
  final Future<void> Function(String id, bool approve) onReview;

  @override
  Widget build(BuildContext context) {
    if (absences.isEmpty) {
      return const AppEmptyState(
        message: 'No hay ausencias pendientes',
        icon: CupertinoIcons.checkmark_seal,
      );
    }

    return AppSoftCard(
      child: Column(
        children: [
          for (var i = 0; i < absences.length; i++)
            _AbsenceAdminRow(
              absence: absences[i],
              showDivider: i > 0,
              onApprove: () => onReview(absences[i].id, true),
              onReject: () => onReview(absences[i].id, false),
            ),
        ],
      ),
    );
  }
}

class _AbsenceAdminRow extends StatelessWidget {
  const _AbsenceAdminRow({
    required this.absence,
    required this.showDivider,
    required this.onApprove,
    required this.onReject,
  });

  final AbsenceRequest absence;
  final bool showDivider;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('d MMM yyyy', 'es');
    final range = absence.startDate.year == absence.endDate.year &&
            absence.startDate.month == absence.endDate.month &&
            absence.startDate.day == absence.endDate.day
        ? dateFmt.format(absence.startDate)
        : '${dateFmt.format(absence.startDate)} – ${dateFmt.format(absence.endDate)}';

    return Column(
      children: [
        if (showDivider)
          const Divider(height: 1, indent: 16, color: AppTheme.border),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                absence.employeeName ?? 'Empleado',
                style: AppTheme.rowTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                absenceTypeLabel(l10n, absence.absenceType),
                style: AppTheme.rowMeta(context),
              ),
              const SizedBox(height: 4),
              Text(range, style: AppTheme.rowMeta(context)),
              const SizedBox(height: 6),
              Text(absence.reason, style: AppTheme.rowMeta(context)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: AppTheme.outlinedButtonStyle().copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(40)),
                      ),
                      child: Text(l10n.reject),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      style: AppTheme.filledButtonStyle().copyWith(
                        minimumSize:
                            const WidgetStatePropertyAll(Size.fromHeight(40)),
                      ),
                      child: Text(l10n.approve),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExportTab extends StatelessWidget {
  const _ExportTab({required this.onExport});

  final Future<void> Function(String format) onExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Exporta los registros de los últimos 30 días.',
          style: AppTheme.subtitle(context),
        ),
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: 'Exportar JSON',
          onTap: () => onExport('json'),
        ),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: 'Exportar XML',
          onTap: () => onExport('xml'),
        ),
        const SizedBox(height: 12),
        AppSecondaryButton(
          label: 'Exportar PDF',
          onTap: () => onExport('pdf'),
        ),
      ],
    );
  }
}

