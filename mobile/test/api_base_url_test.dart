import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/services/api_client.dart';

void main() {
  test('web uses localhost', () {
    expect(resolveApiBaseUrl(isWeb: true), 'http://localhost:3000/api');
  });

  test('Android emulator uses the host alias', () {
    expect(resolveApiBaseUrl(isWeb: false), 'http://10.0.2.2:3000/api');
  });

  test('an explicit value wins', () {
    expect(
      resolveApiBaseUrl(isWeb: true, override: 'http://192.168.1.10:3000/api'),
      'http://192.168.1.10:3000/api',
    );
  });
}
