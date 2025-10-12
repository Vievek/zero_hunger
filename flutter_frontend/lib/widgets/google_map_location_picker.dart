import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GoogleMapLocationPicker extends StatefulWidget {
  final String? initialAddress;
  final LatLng? initialLocation;
  final Function(LatLng location, String address) onLocationSelected;
  final String googleApiKey;
  final FocusNode? addressFocusNode;

  const GoogleMapLocationPicker({
    super.key,
    this.initialAddress,
    this.initialLocation,
    required this.onLocationSelected,
    required this.googleApiKey,
    this.addressFocusNode,
  });

  @override
  State<GoogleMapLocationPicker> createState() =>
      _GoogleMapLocationPickerState();
}

class _GoogleMapLocationPickerState extends State<GoogleMapLocationPicker> {
  LatLng? _selectedLocation;
  final TextEditingController _addressController = TextEditingController();
  bool _isGettingLocation = false;
  late FocusNode _internalFocusNode;
  FocusNode get _effectiveFocusNode =>
      widget.addressFocusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();

    // Initialize focus node
    _internalFocusNode = FocusNode();

    _addressController.text = widget.initialAddress ?? '';
    _selectedLocation = widget.initialLocation;

    if (_selectedLocation == null) {
      _getCurrentLocation();
    }
  }

  @override
  void didUpdateWidget(GoogleMapLocationPicker oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controller text only if the initialAddress changed meaningfully
    if (oldWidget.initialAddress != widget.initialAddress &&
        _addressController.text != widget.initialAddress) {
      _addressController.text = widget.initialAddress ?? '';
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    // Only dispose internal focus node, not the one passed from parent
    _internalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng currentLocation =
          LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLocation;
      });

      await _getAddressFromLatLng(currentLocation);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get current location: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark placemark = placemarks.first;
        String address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country
        ].where((part) => part != null && part.isNotEmpty).join(', ');

        setState(() {
          _addressController.text = address;
        });

        // Notify parent widget
        widget.onLocationSelected(latLng, address);
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  void _onPlaceSelected(Prediction prediction) async {
    try {
      // Use geocoding to get coordinates from place description
      List<Location> locations =
          await locationFromAddress(prediction.description!);

      if (locations.isNotEmpty) {
        final Location location = locations.first;
        final LatLng newLocation =
            LatLng(location.latitude, location.longitude);

        setState(() {
          _selectedLocation = newLocation;
          _addressController.text = prediction.description!;
        });

        // Notify parent widget
        widget.onLocationSelected(newLocation, prediction.description!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location details: $e')),
        );
      }
    }
  }

  Widget _buildAddressTextField() {
    return Focus(
      focusNode: _effectiveFocusNode,
      child: Builder(
        builder: (context) {
          return GooglePlaceAutoCompleteTextField(
            textEditingController: _addressController,
            googleAPIKey: widget.googleApiKey,
            inputDecoration: InputDecoration(
              hintText: 'Search for a location...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              // Add clear button manually since we can't use focus node directly
              suffixIcon: _addressController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _addressController.clear();
                        _effectiveFocusNode.requestFocus();
                      },
                    )
                  : null,
            ),
            debounceTime: 800,
            countries: const ["lk"],
            isLatLngRequired: true,
            getPlaceDetailWithLatLng: (Prediction prediction) {
              _onPlaceSelected(prediction);
            },
            itemClick: (Prediction prediction) {
              _addressController.text = prediction.description!;
              _onPlaceSelected(prediction);
              // Keep focus on the address field after selection
              _effectiveFocusNode.requestFocus();
            },
            seperatedBuilder: const Divider(height: 1),
            containerHorizontalPadding: 0,
            itemBuilder: (context, index, Prediction prediction) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade100,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.grey.shade600, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        prediction.description ?? "",
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
            isCrossBtnShown: false, // We handle clear button manually
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pickup Location *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Google Places Search Field with proper focus control
        _buildAddressTextField(),

        const SizedBox(height: 12),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGettingLocation ? null : _getCurrentLocation,
                icon: _isGettingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed),
                label: Text(
                    _isGettingLocation ? 'Getting...' : 'Current Location'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (_selectedLocation != null) {
                    _showLocationPreview();
                  }
                },
                icon: const Icon(Icons.preview),
                label: const Text('Preview'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Location Status Display
        if (_selectedLocation != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade600, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location Selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        _addressController.text.isNotEmpty
                            ? _addressController.text
                            : 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Help Text
        const Text(
          'Search for a location above or use current location to set pickup address.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  void _showLocationPreview() {
    if (_selectedLocation == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selected Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${_addressController.text}'),
            const SizedBox(height: 8),
            Text('Latitude: ${_selectedLocation!.latitude.toStringAsFixed(6)}'),
            Text(
                'Longitude: ${_selectedLocation!.longitude.toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
