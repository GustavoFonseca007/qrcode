import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

class FirebaseAnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver getAnalyticsObserver() =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  void logEvent(String eventName, Map<String, dynamic>? parameters) {
    _analytics.logEvent(name: eventName, parameters: parameters);
  }
}

final FirebaseAnalyticsService firebaseAnalyticsService =
    FirebaseAnalyticsService();
