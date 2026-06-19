import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitxem/models/billing_plan.dart';
import 'package:fitxem/providers/auth_provider.dart';
import 'package:fitxem/services/api_client.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/app_page.dart';
import 'package:url_launcher/url_launcher.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  Map<String, dynamic>? _org;
  int _employeeCount = 5;
  BillingPeriod _period = BillingPeriod.yearly;
  PlanTier _selectedTier = PlanTier.profesional;
  bool _loading = true;
  bool _checkoutLoading = false;
  String? _error;
  int? _expandedFaq;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final org = await api.getOrg();
      var seats = 5;
      if (ref.read(authProvider).isAdmin) {
        try {
          final employees = await api.listEmployees();
          seats = employees.length.clamp(1, 999);
        } catch (_) {}
      }
      if (!mounted) return;
      final current = BillingPlan.tierFromSubscription(
        org['subscription_tier'] as String?,
      );
      setState(() {
        _org = org;
        _employeeCount = seats;
        if (current != PlanTier.trial) _selectedTier = current;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  PlanTier get _currentTier =>
      BillingPlan.tierFromSubscription(_org?['subscription_tier'] as String?);

  bool get _isTrial => _currentTier == PlanTier.trial;

  BillingPlan? get _selectedPlan {
    for (final p in BillingPlan.plans) {
      if (p.tier == _selectedTier) return p;
    }
    return null;
  }

  double get _totalPrice {
    final plan = _selectedPlan;
    if (plan == null) return 0;
    final perSeat = plan.priceFor(_period) * _employeeCount;
    if (_period == BillingPeriod.yearly) return perSeat * 12;
    return perSeat;
  }

  Future<void> _startCheckout() async {
    final auth = ref.read(authProvider);
    if (!auth.isAdmin) {
      _showSnack('Solo un administrador puede gestionar la suscripción');
      return;
    }

    final plan = _selectedPlan;
    if (plan == null) return;

    if (_currentTier == _selectedTier && !_isTrial) {
      _showSnack('Ya tienes este plan activo');
      return;
    }

    setState(() => _checkoutLoading = true);
    try {
      final res = await ref.read(apiClientProvider).createCheckoutSession(
            planId: plan.tier.name,
            seatCount: _employeeCount,
            period: _period.name,
          );
      final url = res['url'] as String?;
      if (url != null && await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        final msg = res['message'] as String? ??
            'Checkout en preparación. Contacta con soporte@fitxem.com';
        _showSnack(msg);
      }
    } catch (e) {
      _showSnack('No se pudo iniciar el pago. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _checkoutLoading = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoadingPage();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.pagePadding,
                    AppTheme.pageTopPadding,
                    AppTheme.pagePadding,
                    16,
                  ),
                  children: [
                    Row(
                      children: [
                        const AppBackButton(),
                        const Spacer(),
                        _TrustPill(
                          icon: CupertinoIcons.lock_shield,
                          label: 'Pago seguro',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_error != null) ...[
                      AppErrorBanner(message: _error!, onRetry: _load),
                      const SizedBox(height: 20),
                    ],
                    _CurrentPlanBanner(
                      tier: _currentTier,
                      orgName: _org?['legal_name'] as String?,
                      employeeCount: _employeeCount,
                      isTrial: _isTrial,
                    ),
                    const SizedBox(height: 28),
                    Text('Elige tu plan', style: AppTheme.pageTitle(context)),
                    const SizedBox(height: 8),
                    Text(
                      'Precio por empleado. Escala cuando crezcas, sin permanencia.',
                      style: AppTheme.subtitle(context),
                    ),
                    const SizedBox(height: 20),
                    _PeriodToggle(
                      period: _period,
                      onChanged: (p) => setState(() => _period = p),
                    ),
                    const SizedBox(height: 24),
                    ...BillingPlan.plans.map(
                      (plan) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PlanCard(
                          plan: plan,
                          period: _period,
                          selected: _selectedTier == plan.tier,
                          isCurrent: _currentTier == plan.tier && !_isTrial,
                          onTap: () => setState(() => _selectedTier = plan.tier),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SeatStepper(
                      count: _employeeCount,
                      onChanged: (v) => setState(() => _employeeCount = v),
                    ),
                    const SizedBox(height: 28),
                    _SocialProof(),
                    const SizedBox(height: 28),
                    Text('Comparativa', style: AppTheme.sectionTitle(context)),
                    const SizedBox(height: 12),
                    const _FeatureComparison(),
                    const SizedBox(height: 28),
                    Text('Preguntas frecuentes', style: AppTheme.sectionTitle(context)),
                    const SizedBox(height: 12),
                    ..._faqs.asMap().entries.map(
                          (e) => _FaqTile(
                            question: e.value.$1,
                            answer: e.value.$2,
                            expanded: _expandedFaq == e.key,
                            onTap: () => setState(
                              () => _expandedFaq =
                                  _expandedFaq == e.key ? null : e.key,
                            ),
                          ),
                        ),
                    const SizedBox(height: 16),
                    _TrustRow(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _CheckoutBar(
              plan: _selectedPlan,
              period: _period,
              total: _totalPrice,
              employeeCount: _employeeCount,
              isAdmin: ref.watch(authProvider).isAdmin,
              isCurrentPlan: _currentTier == _selectedTier && !_isTrial,
              loading: _checkoutLoading,
              onCheckout: _startCheckout,
            ),
          ],
        ),
      ),
    );
  }
}

const _faqs = [
  (
    '¿Puedo cambiar de plan en cualquier momento?',
    'Sí. Sube o baja de plan cuando quieras. Los cambios se prorratean automáticamente en tu próxima factura.',
  ),
  (
    '¿Hay permanencia o penalización?',
    'No. Cancela cuando quieras desde el portal de facturación. Sin letra pequeña.',
  ),
  (
    '¿Cómo se calcula el precio?',
    'Pagas por empleado activo al mes. Si contratas o das de baja empleados, el importe se ajusta.',
  ),
  (
    '¿Incluye factura con IVA?',
    'Sí. Recibirás factura mensual o anual con todos los datos fiscales de tu empresa.',
  ),
  (
    '¿Qué pasa cuando termina la prueba?',
    'Puedes seguir con el plan que elijas. Si no activas uno, el acceso se limita a consulta de historial.',
  ),
];

class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({
    required this.tier,
    required this.isTrial,
    this.orgName,
    required this.employeeCount,
  });

  final PlanTier tier;
  final bool isTrial;
  final String? orgName;
  final int employeeCount;

  @override
  Widget build(BuildContext context) {
    final label = BillingPlan.subscriptionLabel(
      isTrial ? 'trial' : tier.name,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isTrial
              ? [const Color(0xFF1C1C1E), const Color(0xFF2D2D30)]
              : [AppTheme.greenText, AppTheme.green],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isTrial ? 'PRUEBA ACTIVA' : 'PLAN ACTUAL',
                  style: AppTheme.greeting(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isTrial) ...[
                const Spacer(),
                Icon(
                  CupertinoIcons.time,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  '14 días gratis',
                  style: AppTheme.badge(context).copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: AppTheme.pageTitle(context).copyWith(
              color: Colors.white,
              fontSize: 26,
            ),
          ),
          if (orgName != null) ...[
            const SizedBox(height: 4),
            Text(
              orgName!,
              style: AppTheme.subtitle(context).copyWith(
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            isTrial
                ? 'Activa un plan antes de que termine la prueba para no perder el fichaje.'
                : '$employeeCount empleado${employeeCount == 1 ? '' : 's'} · Facturación ${_periodLabel()}',
            style: AppTheme.subtitle(context).copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel() => 'activa';
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final BillingPeriod period;
  final ValueChanged<BillingPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppSegmentedTabs(
          labels: const ['Mensual', 'Anual'],
          selectedIndex: period == BillingPeriod.monthly ? 0 : 1,
          onSelected: (i) => onChanged(
            i == 0 ? BillingPeriod.monthly : BillingPeriod.yearly,
          ),
        ),
        Positioned(
          top: -10,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '−20%',
              style: AppTheme.badge(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.period,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final BillingPlan plan;
  final BillingPeriod period;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppTheme.green : AppTheme.border;
    final bgColor = selected ? AppTheme.greenMuted.withValues(alpha: 0.35) : AppTheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: borderColor,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.green.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(plan.name, style: AppTheme.rowTitle(context)),
                          if (plan.isPopular) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.textPrimary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Popular',
                                style: AppTheme.badge(context).copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.greenMuted,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Actual',
                                style: AppTheme.badge(context).copyWith(
                                  color: AppTheme.greenText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(plan.tagline, style: AppTheme.rowMeta(context)),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppTheme.green : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppTheme.green : AppTheme.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.priceLabel(period),
                  style: AppTheme.pageTitle(context).copyWith(fontSize: 28),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '/empleado/mes',
                    style: AppTheme.rowMeta(context),
                  ),
                ),
              ],
            ),
            if (period == BillingPeriod.yearly) ...[
              const SizedBox(height: 4),
              Text(
                'Facturado anualmente',
                style: AppTheme.badge(context).copyWith(
                  color: AppTheme.greenText,
                  fontSize: 11,
                ),
              ),
            ],
            const SizedBox(height: 14),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_alt,
                      size: 16,
                      color: selected ? AppTheme.greenText : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(f, style: AppTheme.rowMeta(context)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeatStepper extends StatelessWidget {
  const _SeatStepper({required this.count, required this.onChanged});

  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppSoftCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Empleados a facturar', style: AppTheme.rowTitle(context)),
                  const SizedBox(height: 2),
                  Text(
                    'Ajusta según tu plantilla actual',
                    style: AppTheme.rowMeta(context),
                  ),
                ],
              ),
            ),
            _StepButton(
              icon: CupertinoIcons.minus,
              onTap: count > 1 ? () => onChanged(count - 1) : null,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: AppTheme.rowTitle(context).copyWith(fontSize: 18),
              ),
            ),
            _StepButton(
              icon: CupertinoIcons.plus,
              onTap: count < 999 ? () => onChanged(count + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.surfaceMuted : AppTheme.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? AppTheme.textPrimary : AppTheme.textTertiary,
        ),
      ),
    );
  }
}

class _SocialProof extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppSoftCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _AvatarStack(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+500 pymes en España',
                    style: AppTheme.rowTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fichan con Fitxem cada día',
                    style: AppTheme.rowMeta(context),
                  ),
                ],
              ),
            ),
            Row(
              children: List.generate(
                5,
                (i) => Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                  child: Icon(
                    CupertinoIcons.star_fill,
                    size: 14,
                    color: i < 4 ? const Color(0xFFFBBF24) : AppTheme.border,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFF22C55E),
      Color(0xFF3B82F6),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
    ];
    return SizedBox(
      width: 72,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 18.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    ['A', 'M', 'J', 'L'][i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeatureComparison extends StatelessWidget {
  const _FeatureComparison();

  static const _rows = [
    ('Fichaje legal RD 8/2019', true, true, true),
    ('Historial y exportación', true, true, true),
    ('Horarios y plantillas', false, true, true),
    ('Ausencias e incidencias', false, true, true),
    ('Recordatorios', false, true, true),
    ('Soporte prioritario', false, false, true),
    ('API e integraciones', false, false, true),
  ];

  @override
  Widget build(BuildContext context) {
    return AppSoftCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(16),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder(
            horizontalInside: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
          ),
          children: [
            TableRow(
              children: [
                const SizedBox(width: 140),
                _ColHeader('Esencial'),
                _ColHeader('Pro', highlight: true),
                _ColHeader('Empresa'),
              ],
            ),
            ..._rows.map(
              (row) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Text(row.$1, style: AppTheme.rowMeta(context)),
                  ),
                  _CheckCell(row.$2),
                  _CheckCell(row.$3),
                  _CheckCell(row.$4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader(this.label, {this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTheme.rowTitle(context).copyWith(
          fontSize: 12,
          color: highlight ? AppTheme.greenText : AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _CheckCell extends StatelessWidget {
  const _CheckCell(this.value);

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Icon(
        value ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.minus,
        size: 18,
        color: value ? AppTheme.green : AppTheme.textTertiary,
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppSoftCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(question, style: AppTheme.rowTitle(context)),
                    ),
                    Icon(
                      expanded
                          ? CupertinoIcons.chevron_up
                          : CupertinoIcons.chevron_down,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(answer, style: AppTheme.rowMeta(context)),
                  ),
                  crossFadeState: expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: const [
        _TrustPill(icon: CupertinoIcons.creditcard, label: 'Stripe'),
        _TrustPill(icon: CupertinoIcons.xmark_circle, label: 'Sin permanencia'),
        _TrustPill(icon: CupertinoIcons.doc_text, label: 'Factura IVA'),
      ],
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: AppTheme.badge(context)),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.plan,
    required this.period,
    required this.total,
    required this.employeeCount,
    required this.isAdmin,
    required this.isCurrentPlan,
    required this.loading,
    required this.onCheckout,
  });

  final BillingPlan? plan;
  final BillingPeriod period;
  final double total;
  final int employeeCount;
  final bool isAdmin;
  final bool isCurrentPlan;
  final bool loading;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final totalLabel = total > 0
        ? '${total.toStringAsFixed(2).replaceAll('.', ',')} €'
        : '—';
    final periodSuffix = period == BillingPeriod.yearly ? '/año' : '/mes';

    String ctaLabel;
    if (!isAdmin) {
      ctaLabel = 'Contacta con tu administrador';
    } else if (isCurrentPlan) {
      ctaLabel = 'Plan actual';
    } else if (plan?.isPopular == true) {
      ctaLabel = 'Empezar con Profesional';
    } else {
      ctaLabel = 'Continuar al pago';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$totalLabel$periodSuffix',
                        style: AppTheme.rowTitle(context).copyWith(fontSize: 20),
                      ),
                      Text(
                        '$employeeCount empleado${employeeCount == 1 ? '' : 's'} · ${plan?.name ?? ''}',
                        style: AppTheme.rowMeta(context),
                      ),
                    ],
                  ),
                ),
                if (period == BillingPeriod.yearly && total > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.greenMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ahorras 20%',
                      style: AppTheme.badge(context).copyWith(
                        color: AppTheme.greenText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: (!isAdmin || isCurrentPlan || loading) ? null : onCheckout,
                style: AppTheme.filledButtonStyle().copyWith(
                  backgroundColor: WidgetStatePropertyAll(
                    plan?.isPopular == true && !isCurrentPlan
                        ? AppTheme.green
                        : AppTheme.textPrimary,
                  ),
                ),
                child: loading
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : Text(ctaLabel),
              ),
            ),
            if (isAdmin && !isCurrentPlan) ...[
              const SizedBox(height: 8),
              Text(
                'Pago seguro con Stripe · Cancela cuando quieras',
                textAlign: TextAlign.center,
                style: AppTheme.badge(context).copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
