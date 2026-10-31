import 'api_client.dart';

/// A short message for a failed request, safe to show on screen.
String errorMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}
