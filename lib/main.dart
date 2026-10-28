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
  Timer? _liveGpsTimer;
  Timer? _simulationTimer;

  // Default initial position (Mayor Mohammad Hanif Flyover / Gulistan entry)
  static const LatLng _initialPosition = LatLng(23.722621, 90.415511);

  LatLng? _currentPosition;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final List<LatLng> _polylineCoordinates = [];

  bool _isInfoWindowOpen = true;
  bool _isSimulating = true; // Enabled by default for easy demo/testing on emulators
  bool _isSimulationPaused = false;
  int _simulationIndex = 0;

  // 131 high-precision road coordinates along Mayor Mohammad Hanif Flyover / Jatrabari Road
  // Every single waypoint strictly lies on the road asphalt with ~25m realistic spacing
  static const List<LatLng> _roadWaypoints = [
    LatLng(23.722621, 90.415511),
    LatLng(23.722522, 90.415722),
    LatLng(23.722437, 90.415899),
    LatLng(23.722353, 90.416076),
    LatLng(23.722273, 90.416307),
    LatLng(23.722236, 90.416479),
    LatLng(23.722198, 90.416674),
    LatLng(23.722167, 90.416884),
    LatLng(23.722135, 90.417139),
    LatLng(23.722103, 90.417394),
    LatLng(23.722071, 90.417649),
    LatLng(23.722035, 90.417942),
    LatLng(23.721999, 90.418235),
    LatLng(23.721967, 90.418509),
    LatLng(23.721934, 90.418782),
    LatLng(23.721902, 90.419037),
    LatLng(23.721871, 90.419292),
    LatLng(23.721840, 90.419497),
    LatLng(23.721810, 90.419702),
    LatLng(23.721768, 90.419913),
    LatLng(23.721726, 90.420032),
    LatLng(23.721682, 90.420135),
    LatLng(23.721629, 90.420212),
    LatLng(23.721600, 90.420249),
    LatLng(23.721575, 90.420270),
    LatLng(23.721549, 90.420290),
    LatLng(23.721503, 90.420315),
    LatLng(23.721468, 90.420330),
    LatLng(23.721430, 90.420337),
    LatLng(23.721394, 90.420339),
    LatLng(23.721189, 90.420297),
    LatLng(23.721004, 90.420247),
    LatLng(23.720818, 90.420196),
    LatLng(23.720784, 90.420190),
    LatLng(23.720739, 90.420182),
    LatLng(23.720547, 90.420160),
    LatLng(23.720505, 90.420155),
    LatLng(23.720246, 90.420149),
    LatLng(23.719956, 90.420164),
    LatLng(23.719930, 90.420165),
    LatLng(23.719632, 90.420213),
    LatLng(23.719457, 90.420259),
    LatLng(23.719388, 90.420278),
    LatLng(23.719344, 90.420289),
    LatLng(23.719017, 90.420359),
    LatLng(23.718932, 90.420387),
    LatLng(23.718781, 90.420423),
    LatLng(23.718651, 90.420454),
    LatLng(23.718452, 90.420567),
    LatLng(23.718382, 90.420609),
    LatLng(23.718253, 90.420718),
    LatLng(23.718105, 90.420829),
    LatLng(23.717840, 90.421019),
    LatLng(23.717731, 90.421074),
    LatLng(23.717622, 90.421139),
    LatLng(23.717412, 90.421281),
    LatLng(23.717223, 90.421424),
    LatLng(23.717035, 90.421566),
    LatLng(23.716834, 90.421718),
    LatLng(23.716622, 90.421872),
    LatLng(23.716409, 90.422025),
    LatLng(23.716197, 90.422179),
    LatLng(23.716148, 90.422234),
    LatLng(23.716114, 90.422307),
    LatLng(23.716083, 90.422383),
    LatLng(23.716026, 90.422555),
    LatLng(23.715936, 90.422793),
    LatLng(23.715817, 90.423003),
    LatLng(23.715695, 90.423207),
    LatLng(23.715562, 90.423403),
    LatLng(23.715399, 90.423630),
    LatLng(23.715362, 90.423682),
    LatLng(23.715324, 90.423733),
    LatLng(23.715282, 90.423813),
    LatLng(23.715215, 90.423928),
    LatLng(23.715129, 90.424126),
    LatLng(23.715044, 90.424323),
    LatLng(23.714965, 90.424531),
    LatLng(23.714887, 90.424738),
    LatLng(23.714809, 90.424945),
    LatLng(23.714730, 90.425153),
    LatLng(23.714714, 90.425204),
    LatLng(23.714691, 90.425270),
    LatLng(23.714675, 90.425315),
    LatLng(23.714638, 90.425437),
    LatLng(23.714511, 90.425739),
    LatLng(23.714409, 90.425915),
    LatLng(23.714220, 90.426208),
    LatLng(23.714091, 90.426381),
    LatLng(23.713969, 90.426570),
    LatLng(23.713846, 90.426759),
    LatLng(23.713737, 90.426907),
    LatLng(23.713628, 90.427055),
    LatLng(23.713504, 90.427237),
    LatLng(23.713379, 90.427419),
    LatLng(23.713265, 90.427584),
    LatLng(23.713150, 90.427749),
    LatLng(23.712993, 90.427953),
    LatLng(23.712836, 90.428156),
    LatLng(23.712765, 90.428259),
    LatLng(23.712599, 90.428474),
    LatLng(23.712586, 90.428501),
    LatLng(23.712564, 90.428525),
    LatLng(23.712452, 90.428701),
    LatLng(23.712340, 90.428877),
    LatLng(23.712228, 90.429053),
    LatLng(23.712111, 90.429221),
    LatLng(23.711995, 90.429390),
    LatLng(23.711949, 90.429459),
    LatLng(23.711840, 90.429620),
    LatLng(23.711795, 90.429681),
    LatLng(23.711676, 90.429865),
    LatLng(23.711525, 90.430140),
    LatLng(23.711453, 90.430269),
    LatLng(23.711394, 90.430402),
    LatLng(23.711319, 90.430620),
    LatLng(23.711244, 90.430837),
    LatLng(23.711181, 90.431045),
    LatLng(23.711147, 90.431168),
    LatLng(23.711091, 90.431391),
    LatLng(23.711035, 90.431613),
    LatLng(23.710979, 90.431836),
    LatLng(23.710936, 90.432034),
    LatLng(23.710894, 90.432231),
    LatLng(23.710861, 90.432419),
    LatLng(23.711106, 90.432434),
    LatLng(23.711265, 90.432415),
    LatLng(23.711419, 90.432386),
    LatLng(23.711515, 90.432371),
    LatLng(23.711699, 90.432339),
    LatLng(23.711680, 90.431988),
  ];

  @override
  void initState() {
    super.initState();
    // Start tracking immediately upon load
    _startTrackingSession();
  }

  @override
  void dispose() {
    _liveGpsTimer?.cancel();
    _simulationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startTrackingSession() {
    if (_isSimulating) {
      _startRoadSimulation();
    } else {
      _startLiveGpsTracking();
    }
  }

  /// Starts realistic road simulation advancing along actual road waypoints every 1.5 seconds
  void _startRoadSimulation() {
    _liveGpsTimer?.cancel();
    _simulationTimer?.cancel();

    // Place marker at initial road waypoint if not already started
    if (_simulationIndex >= _roadWaypoints.length) {
      _simulationIndex = 0;
    }
    final startPt = _roadWaypoints[_simulationIndex];
    _applyNewLocation(
      newPosition: startPt,
      latitude: startPt.latitude,
      longitude: startPt.longitude,
      isInitial: _polylineCoordinates.isEmpty,
    );

    // Realistic navigation step interval: advances every 1.5s (~60 km/h)
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (_isSimulationPaused) return;

      _simulationIndex = (_simulationIndex + 1) % _roadWaypoints.length;
      final nextPt = _roadWaypoints[_simulationIndex];
      _applyNewLocation(
        newPosition: nextPt,
        latitude: nextPt.latitude,
        longitude: nextPt.longitude,
      );
    });
  }

  /// Task 2: Real-Time Location Updates
  /// Fetches the user's current GPS location immediately and then every 10 seconds.
  void _startLiveGpsTracking() {
    _simulationTimer?.cancel();
    _liveGpsTimer?.cancel();

    // Fetch initial live location immediately
    _fetchAndUpdateLocation(isInitial: true);

    // Periodic GPS fetch every 10 seconds as required by assignment specification
    _liveGpsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchAndUpdateLocation();
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
            const SnackBar(content: Text('Location permission denied.')),
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

    setState(() {
      _currentPosition = newPosition;

      // Task 3: Polyline Tracking
      // Adds new coordinate along the route, connecting past points to current point
      if (_polylineCoordinates.isEmpty) {
        _polylineCoordinates.add(newPosition);
      } else {
        final double distance = Geolocator.distanceBetween(
          _polylineCoordinates.last.latitude,
          _polylineCoordinates.last.longitude,
          newPosition.latitude,
          newPosition.longitude,
        );
        // Only add if movement is at least 1.0 meter (filters tiny jitter while keeping road fidelity)
        if (distance >= 1.0) {
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
            snippet: '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
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
    // Smoothly animates to the user's current location while preserving zoom level
    _animateCamera(
      newPosition,
      isInitial: isInitial || _polylineCoordinates.length <= 1,
    );

    // Keep InfoWindow open as requested in the assignment demo
    if (_isInfoWindowOpen && _mapController != null) {
      _mapController!.showMarkerInfoWindow(const MarkerId('current_location'));
    }
  }

  /// Updates the Polyline set with the current coordinate list.
  /// Polyline strictly connects the road points with rounded joints and caps
  void _updatePolylineSet() {
    _polylines.clear();
    if (_polylineCoordinates.length >= 2) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('tracking_polyline'),
          points: List<LatLng>.from(_polylineCoordinates),
          color: const Color(0xFF1E88E5), // Clean vibrant navigation blue
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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    final target = _currentPosition ?? _initialPosition;
    _animateCamera(target, isInitial: true);

    // Automatically display InfoWindow upon creation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _mapController != null && _isInfoWindowOpen) {
        _mapController!.showMarkerInfoWindow(const MarkerId('current_location'));
      }
    });
  }

  void _toggleSimulation() {
    setState(() {
      _isSimulating = !_isSimulating;
      _polylineCoordinates.clear();
      _polylines.clear();
      _simulationIndex = 0;
      _isSimulationPaused = false;
    });

    if (_isSimulating) {
      _startRoadSimulation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Road Simulation: Moving smoothly along real road waypoints'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _startLiveGpsTracking();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched to Live GPS Tracking (Updates every 10s)'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _resetPolylineHistory() {
    setState(() {
      _polylineCoordinates.clear();
      if (_currentPosition != null) {
        _polylineCoordinates.add(_currentPosition!);
      }
      _updatePolylineSet();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Polyline history cleared.'),
        duration: Duration(seconds: 1),
      ),
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
                _toggleSimulation();
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
                _resetPolylineHistory();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_simulation',
                child: Row(
                  children: [
                    Icon(
                      _isSimulating ? Icons.gps_fixed : Icons.directions_car,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isSimulating
                          ? 'Switch to Live GPS'
                          : 'Simulate Road Movement',
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
      body: Stack(
        children: [
          // Google Map with padding so default controls do not collide with bottom control card
          GoogleMap(
            padding: const EdgeInsets.only(bottom: 110),
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

          // Bottom Control Card for quick and easy evaluation
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode and Coordinate display row
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isSimulating
                                ? (_isSimulationPaused ? Colors.orange : Colors.green)
                                : Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isSimulating
                              ? (_isSimulationPaused
                                  ? 'Road Simulation (Paused)'
                                  : 'Road Simulation (${_simulationIndex + 1}/${_roadWaypoints.length})')
                              : 'Live GPS (Every 10s)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        if (_currentPosition != null)
                          Text(
                            '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                    const Divider(height: 12),
                    // Quick Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Play / Pause (Simulation only)
                        if (_isSimulating)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: Icon(
                              _isSimulationPaused ? Icons.play_arrow : Icons.pause,
                              size: 18,
                              color: Colors.blue,
                            ),
                            label: Text(
                              _isSimulationPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _isSimulationPaused = !_isSimulationPaused;
                              });
                            },
                          ),

                        // Switch Mode (Simulation <-> Live GPS)
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: Icon(
                            _isSimulating ? Icons.gps_fixed : Icons.directions_car,
                            size: 18,
                            color: Colors.indigo,
                          ),
                          label: Text(
                            _isSimulating ? 'Use Live GPS' : 'Simulate Road',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: _toggleSimulation,
                        ),

                        // Reset Polyline
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          icon: const Icon(
                            Icons.refresh,
                            size: 18,
                            color: Colors.deepOrange,
                          ),
                          label: const Text(
                            'Reset',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            setState(() {
                              _simulationIndex = 0;
                            });
                            _resetPolylineHistory();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
