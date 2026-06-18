import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fitxem/l10n/app_localizations.dart';
import 'package:fitxem/models/clock_event.dart';
import 'package:fitxem/theme/app_theme.dart';
import 'package:fitxem/widgets/marcaje_row.dart';

Future<void> showLocationMapSheet(
  BuildContext context,
  ClockEvent event,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
    ),
    builder: (context) => _LocationMapSheet(event: event),
  );
}

class _LocationMapSheet extends StatelessWidget {
  const _LocationMapSheet({required this.event});

  final ClockEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final height = MediaQuery.sizeOf(context).height * 0.62;
    final lat = event.mapLat;
    final lng = event.mapLng;
    final hasCoords = lat != null && lng != null;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: hasCoords
                    ? FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(lat, lng),
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.fitxem.app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(lat, lng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  CupertinoIcons.location_solid,
                                  color: Color(0xFFEC4899),
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : ColoredBox(
                        color: AppTheme.surfaceMuted,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.location_slash,
                                  size: 40,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.gpsNotRecorded,
                                  textAlign: TextAlign.center,
                                  style: AppTheme.rowMeta(context),
                                ),
                                if (event.workCenter != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    event.workCenter!,
                                    textAlign: TextAlign.center,
                                    style: AppTheme.rowTitle(context),
                                  ),
                                ],
                                if (event.workCenterAddress != null &&
                                    event.workCenterAddress!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    event.workCenterAddress!,
                                    textAlign: TextAlign.center,
                                    style: AppTheme.rowMeta(context),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: DecoratedBox(
              decoration: AppTheme.bordered(radius: AppTheme.radiusMd),
              child: MarcajeRow(
                event: event,
                showDivider: false,
                onLocationTap: null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
