class GoogleMapsConfig {
  // Google Maps API Key for the application
  // This should be the same as the one configured in AndroidManifest.xml
  static const String googleMapsApiKey =
      'AIzaSyC_UXJcMQFbuF2XydPraWO8G_UtkRDYeLQ';

  // Default location (Colombo, Sri Lanka)
  static const double defaultLatitude = 6.9271;
  static const double defaultLongitude = 79.8612;

  // Map configuration
  static const double defaultZoom = 15.0;
  static const double searchRadius = 50.0; // km
}
