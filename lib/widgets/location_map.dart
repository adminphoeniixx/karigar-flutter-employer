import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';

class LocationMap extends StatefulWidget {
  const LocationMap({
    super.key,
    this.initialLocation = const LatLng(13.0827, 80.2707),
    this.onLocationChanged,
  });

  final LatLng initialLocation;
  final ValueChanged<LatLng>? onLocationChanged;

  @override
  State<LocationMap> createState() => _LocationMapState();
}

class _LocationMapState extends State<LocationMap> {
  final MapController _controller = MapController();
  late LatLng _selectedLocation;
  double _zoom = 13;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _select(LatLng point) {
    _controller.move(point, _zoom);
    setState(() => _selectedLocation = point);
    widget.onLocationChanged?.call(point);
  }

  void _changeZoom(double amount) {
    _zoom = (_zoom + amount).clamp(3, 18);
    _controller.move(_controller.camera.center, _zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ColoredBox(
              color: const Color(0xFFE8EEF0),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _controller,
                    options: MapOptions(
                      initialCenter: widget.initialLocation,
                      initialZoom: _zoom,
                      minZoom: 3,
                      maxZoom: 18,
                      onMapReady: () => setState(() => _mapReady = true),
                      onPositionChanged: (camera, hasGesture) {
                        _zoom = camera.zoom;
                        if (hasGesture) {
                          _selectedLocation = camera.center;
                          widget.onLocationChanged?.call(camera.center);
                          setState(() {});
                        }
                      },
                      onTap: (_, point) => _select(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.example.employer_kariger_app',
                        maxNativeZoom: 19,
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution('OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  ),
                  if (!_mapReady)
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _MapButton(
                          icon: LucideIcons.plus,
                          onTap: () => _changeZoom(1),
                        ),
                        const SizedBox(height: 6),
                        _MapButton(
                          icon: LucideIcons.minus,
                          onTap: () => _changeZoom(-1),
                        ),
                      ],
                    ),
                  ),
                  const Center(
                    child: IgnorePointer(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 44),
                        child: Icon(
                          LucideIcons.mapPin,
                          size: 56,
                          color: AppColors.primary,
                          shadows: [Shadow(color: Colors.white, blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                  const Center(
                    child: IgnorePointer(
                      child: Icon(
                        LucideIcons.plus,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Selected: ${_selectedLocation.latitude.toStringAsFixed(5)}, '
          '${_selectedLocation.longitude.toStringAsFixed(5)}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20)),
      ),
    );
  }
}
