import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/absence_request.dart';
import 'package:fitxem/models/vacation_balance.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/request_labels.dart';

class AusenciasScreen extends ConsumerStatefulWidget {
  const AusenciasScreen({super.key});

  @override
  ConsumerState<AusenciasScreen> createState() => _AusenciasScreenState();
}

class _AusenciasScreenState extends ConsumerState<AusenciasScreen> {
  List<AbsenceRequest> _absences = [];
  VacationBalance? _balance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final api = ref.read(apiClientProvider);
      final list = await api.listMyAbsences();
      final balance = await api.getVacationBalance();
      if (!mounted) return;
      setState(() {
        _absences = list;
        _balance = balance;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('d MMM yyyy', 'es');

    if (_loading && _absences.isEmpty) return const AppLoadingPage();

    return AppPage(
      onRefresh: _load,
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Icon(
              CupertinoIcons.back,
              size: 18,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppPageHeader(
          title: l10n.myAbsences,
          subtitle: 'Vacaciones, bajas y permisos.',
        ),
        const SizedBox(height: 20),
        if (_balance != null)
          AppSoftCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.sun_max,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vacaciones ${_balance!.year}',
                          style: AppTheme.rowTitle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_balance!.remaining} días disponibles · '
                          '${_balance!.used} usados de ${_balance!.annual}',
                          style: AppTheme.rowMeta(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_balance != null) const SizedBox(height: 16),
        AppPrimaryButton(
          label: l10n.requestAbsence,
          onTap: () => context.push('/ausencias/new'),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AppErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 16),
        ],
        if (_absences.isEmpty)
          const AppEmptyState(
            message: 'No tienes ausencias registradas',
            icon: CupertinoIcons.sun_max,
          )
        else
          AppSoftCard(
            child: Column(
              children: [
                for (var i = 0; i < _absences.length; i++)
                  _AbsenceRow(
                    absence: _absences[i],
                    dateFmt: dateFmt,
                    showDivider: i > 0,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AbsenceRow extends StatelessWidget {
  const _AbsenceRow({
    required this.absence,
    required this.dateFmt,
    required this.showDivider,
  });

  final AbsenceRequest absence;
  final DateFormat dateFmt;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      absenceTypeLabel(l10n, absence.absenceType),
                      style: AppTheme.rowTitle(context),
                    ),
                  ),
                  RequestStatusChip(status: absence.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(range, style: AppTheme.rowMeta(context)),
              const SizedBox(height: 6),
              Text(absence.reason, style: AppTheme.rowMeta(context)),
            ],
          ),
        ),
      ],
    );
  }
}
