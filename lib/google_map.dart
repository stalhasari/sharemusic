import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  final String currentlyPlayingTrack;
  const MapScreen({required this.currentlyPlayingTrack, super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  Location location = Location();
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;
  LocationData? _locationData;
  Marker? userMarker;
  Set<Marker> otherUsersMarkers = {};

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _fetchOtherUsersLocations();
  }

  Future<void> _checkLocationPermission() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    location.enableBackgroundMode(enable: true);
    location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _locationData = currentLocation;
        _updateUserLocationInFirestore();
        _updateUserMarker();
      });
      _updateCameraPosition();
    });

    _setInitialCameraPosition();
    _updateUserMarker();
  }

  Future<void> _updateUserLocationInFirestore() async {
    if (_locationData != null) {
      try {
        await FirebaseFirestore.instance
            .collection('locations')
            .doc('my_user_id')
            .set({
          'latitude': _locationData!.latitude!,
          'longitude': _locationData!.longitude!,
          'currentlyPlayingTrack': widget.currentlyPlayingTrack,
        });
        print('Konum Firestore\'a başarıyla kaydedildi.');
      } catch (e) {
        print('Konum Firestore\'a kaydedilirken hata oluştu: $e');
      }
    }
  }

  void _fetchOtherUsersLocations() {
    FirebaseFirestore.instance
        .collection('locations')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        otherUsersMarkers =
            snapshot.docs.where((doc) => doc.id != 'my_user_id').map((doc) {
          final data = doc.data();
          return Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(data['latitude'], data['longitude']),
            infoWindow: InfoWindow(title: data['currentlyPlayingTrack']),
          );
        }).toSet();
      });
    });
  }

  void _updateUserMarker() {
    if (_locationData != null) {
      setState(() {
        userMarker = Marker(
          markerId: const MarkerId('userLocation'),
          position: LatLng(_locationData!.latitude!, _locationData!.longitude!),
          infoWindow: InfoWindow(title: widget.currentlyPlayingTrack),
          onTap: () {
            mapController.showMarkerInfoWindow(const MarkerId('userLocation'));
          },
        );
      });
    }
  }

  Future<void> _setInitialCameraPosition() async {
    if (_locationData != null && mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_locationData!.latitude!, _locationData!.longitude!),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void _updateCameraPosition() {
    if (_locationData != null && mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_locationData!.latitude!, _locationData!.longitude!),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _setInitialCameraPosition();
    _updateUserMarker();
  }

  void _zoomToUserLocation() {
    if (_locationData != null && mapController != null) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_locationData!.latitude!, _locationData!.longitude!),
            zoom: 15.0,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Screen'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _zoomToUserLocation,
        tooltip: 'Zoom to Your Location',
        child: Icon(Icons.location_searching),
      ),
      body: GoogleMap(
        myLocationButtonEnabled: true,
        myLocationEnabled: true,
        initialCameraPosition: CameraPosition(
          target: _locationData != null
              ? LatLng(_locationData!.latitude!, _locationData!.longitude!)
              : const LatLng(0, 0),
          zoom: 15.0,
        ),
        markers: userMarker != null
            ? {userMarker!, ...otherUsersMarkers}
            : {...otherUsersMarkers},
        onMapCreated: _onMapCreated,
      ),
    );
  }
}
