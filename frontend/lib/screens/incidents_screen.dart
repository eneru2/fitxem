import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/incident_request.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:fitxem/widgets/request_labels.dart';

class IncidentsScreen extends ConsumerStatefulWidget {
  const IncidentsScreen({super.key});

  @override
  ConsumerState<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends ConsumerState<IncidentsScreen> {
  List<IncidentRequest> _incidents = [];
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
      final list = await ref.read(apiClientProvider).listMyIncidents();
      if (!mounted) return;
      setState(() => _incidents = list);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat('d MMM yyyy, HH:mm', 'es');

    if (_loading && _incidents.isEmpty) return const AppLoadingPage();

    return AppPage(
      onRefresh: _load,
      children: [
        _BackButton(onTap: () => context.pop()),
        const SizedBox(height: 24),
        AppPageHeader(
          title: l10n.myIncidents,
          subtitle: 'Estado de tus solicitudes.',
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AppErrorBanner(message: _error!, onRetry: _load),
          const SizedBox(height: 16),
        ],
        if (_incidents.isEmpty)
          AppEmptyState(
            message: 'No tienes incidencias registradas',
            icon: CupertinoIcons.doc_text,
          )
        else
          AppSoftCard(
            child: Column(
              children: [
                for (var i = 0; i < _incidents.length; i++)
                  _IncidentRow(
                    incident: _incidents[i],
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

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({
    required this.incident,
    required this.dateFmt,
    required this.showDivider,
  });

  final IncidentRequest incident;
  final DateFormat dateFmt;
  final bool showDivider;

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      incidentTypeLabel(l10n, incident.incidentType),
                      style: AppTheme.rowTitle(context),
                    ),
                  ),
                  RequestStatusChip(status: incident.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${eventTypeLabel(l10n, incident.eventType)} · ${dateFmt.format(incident.proposedAt)}',
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
            ],
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}
