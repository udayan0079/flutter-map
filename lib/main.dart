import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Real-Time Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 4,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const RealTimeLocationTrackerScreen(),
    );
  }
}

class RealTimeLocationTrackerScreen extends StatefulWidget {
  const RealTimeLocationTrackerScreen({super.key});

  @override
  State<RealTimeLocationTrackerScreen> createState() =>
      _RealTimeLocationTrackerScreenState();
}

class _RealTimeLocationTrackerScreenState
    extends State<RealTimeLocationTrackerScreen> {
  GoogleMapController? _mapController;
  Timer? _locationTimer;

  // Default initial position (Dhaka - Wari / Flyover from assignment demo)
  static const LatLng _initialPosition = LatLng(23.7216771, 90.4165835);

  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];

  bool _isInfoWindowOpen = false;
  bool _isSimulating = false;
  int _simulationIndex = 0;

  // Demo coordinates along Jatrabari Gulistan Flyover matching the assignment screenshot
  final List<LatLng> _demoWaypoints = const [
    LatLng(23.7216771, 90.4165835),
    LatLng(23.720850, 90.418100),
    LatLng(23.720100, 90.419500),
    LatLng(23.719200, 90.421200),
    LatLng(23.718300, 90.423000),
    LatLng(23.717400, 90.424800),
  ];

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Task 2: Real-Time Location Updates
  /// Fetches the user's current location immediately and then every 10 seconds.
  void _startLocationTracking() {
    // 1. Fetch initial live location immediately
    _fetchAndUpdateLocation(isInitial: true);

    // 2. Fetch location periodically every 10 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isSimulating) {
        _simulateMovementStep();
      } else {
        _fetchAndUpdateLocation();
      }
    });
  }

  /// Checks and requests location permissions and services.
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location services are disabled. Please enable GPS in device settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied.'),
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Location permissions permanently denied. Please allow in app settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return false;
    }

    return true;
  }

  /// Fetches the user's current GPS position using Geolocator.
  Future<void> _fetchAndUpdateLocation({bool isInitial = false}) async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
        ),
      );

      final LatLng newLatLng = LatLng(position.latitude, position.longitude);
      _applyNewLocation(
        newPosition: newLatLng,
        latitude: position.latitude,
        longitude: position.longitude,
        isInitial: isInitial,
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  /// Updates marker, polyline, and animates the map camera.
  Future<void> _applyNewLocation({
    required LatLng newPosition,
    required double latitude,
    required double longitude,
    bool isInitial = false,
  }) async {
    if (!mounted) return;

    // Check if the info window was already open before updating the marker
    bool wasInfoWindowOpen = _isInfoWindowOpen;
    if (_mapController != null) {
      try {
        final isShown = await _mapController!.isMarkerInfoWindowShown(
          const MarkerId('current_location'),
        );
        if (isShown) {
          wasInfoWindowOpen = true;
        }
      } catch (_) {}
    }

    setState(() {
      _currentPosition = newPosition;

      // Task 3: Polyline Tracking
      // Keep updating the polyline connecting previous and current locations
      if (_polylineCoordinates.isEmpty) {
        _polylineCoordinates.add(newPosition);
      } else {
        final double distance = Geolocator.distanceBetween(
          _polylineCoordinates.last.latitude,
          _polylineCoordinates.last.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );
        // Filter out GPS noise/jitter when standing still (less than 2.0 meters)
        // so lines don't drift into building walls
        if (distance >= 2.0) {
          _polylineCoordinates.add(newPosition);
        }
      }

      // Task 2 & Task 4: Marker & Info Window
      // Title: "My Current Location", Snippet: user's latitude and longitude
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position: newPosition,
          infoWindow: InfoWindow(
            title: 'My Current Location',
            snippet: '$latitude,$longitude',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () {
            _isInfoWindowOpen = true;
          },
        ),
      );

      _updatePolylineSet();
    });

    // Task 1: Automatic Map Animation
    // Smoothly animates to the user's current location while preserving user's zoom level
    _animateCamera(
      newPosition,
      isInitial: isInitial || _polylineCoordinates.length <= 1,
    );

    // Keep the info window open if the user had opened it
    if (wasInfoWindowOpen && _mapController != null) {
      _mapController!.showMarkerInfoWindow(const MarkerId('current_location'));
    }
  }

  /// Updates the Polyline set with the current coordinate list.
  /// Only creates a polyline if there are at least 2 points.
  void _updatePolylineSet() {
    _polylines.clear();
    if (_polylineCoordinates.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('tracking_polyline'),
          points: List<LatLng>.from(_polylineCoordinates),
          color: const Color(0xFF2196F3),
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          geodesic: true,
        ),
      );
    }
  }

  /// Smoothly animates the map camera to the target coordinate.
  /// If [isInitial] is true, sets zoom to 16.0.
  /// Otherwise, uses [CameraUpdate.newLatLng] to preserve the user's manual zoom level.
  void _animateCamera(LatLng target, {bool isInitial = false}) {
    if (_mapController == null) return;
    if (isInitial) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 16.0,
          ),
        ),
      );
    } else {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(target),
      );
    }
  }

  /// Called when the Google Map is successfully created.
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // Smoothly animate to initial position with zoom 16.0 upon map creation
    if (_currentPosition != null) {
      _animateCamera(_currentPosition!, isInitial: true);
    } else {
      _animateCamera(_initialPosition, isInitial: true);
    }
  }

  /// Simulates a movement step for testing on emulators or desktops without walking.
  void _simulateMovementStep() {
    _simulationIndex = (_simulationIndex + 1) % _demoWaypoints.length;
    final nextPoint = _demoWaypoints[_simulationIndex];
    _applyNewLocation(
      newPosition: nextPoint,
      latitude: nextPoint.latitude,
      longitude: nextPoint.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Location Tracker'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Options',
            onSelected: (value) {
              if (value == 'toggle_simulation') {
                setState(() {
                  _isSimulating = !_isSimulating;
                  _polylineCoordinates.clear();
                  _polylines.clear();
                  _simulationIndex = 0;
                });
                if (_isSimulating) {
                  final initialDemo = _demoWaypoints[0];
                  _applyNewLocation(
                    newPosition: initialDemo,
                    latitude: initialDemo.latitude,
                    longitude: initialDemo.longitude,
                    isInitial: true,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Simulation enabled: Moving every 10s along demo route'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  _fetchAndUpdateLocation(isInitial: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Live GPS tracking enabled'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'recenter') {
                if (_currentPosition != null) {
                  _animateCamera(_currentPosition!, isInitial: true);
                }
              } else if (value == 'show_info') {
                _isInfoWindowOpen = true;
                _mapController?.showMarkerInfoWindow(
                  const MarkerId('current_location'),
                );
              } else if (value == 'clear_polyline') {
                setState(() {
                  _polylineCoordinates.clear();
                  if (_currentPosition != null) {
                    _polylineCoordinates.add(_currentPosition!);
                  }
                  _updatePolylineSet();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Polyline path reset.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_simulation',
                child: Row(
                  children: [
                    Icon(
                      _isSimulating ? Icons.gps_fixed : Icons.directions_walk,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSimulating
                          ? 'Switch to Live GPS'
                          : 'Simulate Movement (Demo)',
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'show_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Show Info Window'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'recenter',
                child: Row(
                  children: [
                    Icon(Icons.my_location, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Re-center Map'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_polyline',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Clear Polyline History'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 16.0,
        ),
        onMapCreated: _onMapCreated,
        markers: _markers,
        polylines: _polylines,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}
