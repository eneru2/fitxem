enum BillingPeriod { monthly, yearly }

enum PlanTier { trial, esencial, profesional, empresa }

class BillingPlan {
  const BillingPlan({
    required this.tier,
    required this.name,
    required this.tagline,
    required this.pricePerSeatMonthly,
    required this.features,
    this.isPopular = false,
    this.maxSeats,
  });

  final PlanTier tier;
  final String name;
  final String tagline;
  final double pricePerSeatMonthly;
  final List<String> features;
  final bool isPopular;
  final int? maxSeats;

  double priceFor(BillingPeriod period) {
    final base = pricePerSeatMonthly;
    if (period == BillingPeriod.yearly) return base * 0.8;
    return base;
  }

  String priceLabel(BillingPeriod period) {
    final p = priceFor(period);
    if (p == 0) return 'Gratis';
    return '${p.toStringAsFixed(2).replaceAll('.', ',')} €';
  }

  static const plans = [
    BillingPlan(
      tier: PlanTier.esencial,
      name: 'Esencial',
      tagline: 'Fichaje legal sin complicaciones',
      pricePerSeatMonthly: 2.50,
      maxSeats: 25,
      features: [
        'Fichaje entrada, salida y pausas',
        'Historial y calendario',
        'Exportación PDF y Excel',
        'Cumplimiento RD 8/2019',
        'Hasta 25 empleados',
      ],
    ),
    BillingPlan(
      tier: PlanTier.profesional,
      name: 'Profesional',
      tagline: 'Todo lo que una pyme necesita',
      pricePerSeatMonthly: 4.50,
      isPopular: true,
      features: [
        'Todo en Esencial',
        'Horarios y plantillas',
        'Ausencias y vacaciones',
        'Incidencias y correcciones',
        'Recordatorios de fichaje',
        'Empleados ilimitados',
      ],
    ),
    BillingPlan(
      tier: PlanTier.empresa,
      name: 'Empresa',
      tagline: 'Control total para equipos grandes',
      pricePerSeatMonthly: 7.00,
      features: [
        'Todo en Profesional',
        'Soporte prioritario',
        'Onboarding personalizado',
        'Auditoría y trazabilidad ITSS',
        'Multi-sede (próximamente)',
        'API de integración',
      ],
    ),
  ];

  static PlanTier tierFromSubscription(String? tier) {
    return switch (tier?.toLowerCase()) {
      'active' || 'profesional' || 'pro' => PlanTier.profesional,
      'esencial' || 'basic' => PlanTier.esencial,
      'empresa' || 'enterprise' => PlanTier.empresa,
      _ => PlanTier.trial,
    };
  }

  static String subscriptionLabel(String? tier) {
    return switch (tierFromSubscription(tier)) {
      PlanTier.trial => 'Prueba gratuita',
      PlanTier.esencial => 'Esencial',
      PlanTier.profesional => 'Profesional',
      PlanTier.empresa => 'Empresa',
    };
  }
}
