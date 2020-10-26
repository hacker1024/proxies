import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import 'proxy.dart';

/// This class defines functions all proxy providers must implement.
abstract class ProxyProvider {
  const ProxyProvider();

  /// Providers should use this client if they need to make network connections.
  ///
  /// It's recommended to add a line like the following to the implementation:
  /// final _client = ProxyProvider.buildClient();
  @protected
  static Client buildClient([String userAgent]) {
    return userAgent == null
        ? Client()
        : IOClient(HttpClient()..userAgent = userAgent);
  }

  /// Returns a [Proxy] object future, to be used for necessary network operations.
  Future<Proxy> getProxy();

  /// If the proxy provider caches lists of available proxies, invalidate those caches.
  Future<void> invalidateCaches();
}

/// [ProxyProvider]s should extend this class if they require credentials.
abstract class AuthenticatedProxyProvider extends ProxyProvider {
  final String username;
  final String password;

  const AuthenticatedProxyProvider(this.username, this.password);

  /// Validates the current username, before authentication.
  /// Returns null if there's no problem, or a description if there is.
  String validateUsername(String username) =>
      username.isEmpty ? 'Username is empty' : null;

  /// Like [validateUsername], but for the password.
  String validatePassword(String username) =>
      password.isEmpty ? 'Password is empty' : null;
}

/// Providers should throw this if there's a network error.
class ProxyProviderNetworkException implements Exception {}

/// Providers should throw this if there's an authentication error while
/// generating the proxy.
class ProxyProviderAuthenticationException implements Exception {}

/// Providers should throw this if there's an error specific to generating
/// their proxy.
class ProxyProviderSpecificException implements Exception {
  final String message;

  ProxyProviderSpecificException(this.message);

  @override
  String toString() => 'ProxyProviderSpecificException: $message';
}
