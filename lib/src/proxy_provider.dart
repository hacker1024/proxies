import 'dart:io';

import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:meta/meta.dart';

import 'proxy.dart';

/// This class defines functions all proxy providers must implement.
abstract class ProxyProvider {
  const ProxyProvider();

  /// Returns a [Proxy] object future, to be used for necessary network operations.
  Future<Proxy> getProxy();

  /// If the proxy provider caches lists of available proxies, invalidate those caches.
  Future<void> invalidateCaches();

  /// Disposes used resources.
  @mustCallSuper
  void dispose() {}
}

/// [ProxyProvider]s should extend this class if they require credentials.
abstract class AuthenticatedProxyProvider extends ProxyProvider {
  final String username;
  final String password;

  const AuthenticatedProxyProvider(this.username, this.password);

  /// Validates the current username, before authentication.
  ///
  /// Returns null if there's no problem, or a description if there is.
  String? validateUsername(String username) =>
      username.isEmpty ? 'Username is empty' : null;

  /// Like [validateUsername], but for the password.
  String? validatePassword(String username) =>
      password.isEmpty ? 'Password is empty' : null;
}

/// A mixin that provides a lazily instantiated [Client] to use to make HTTP
/// requests.
mixin ProxyProviderClientMixin on ProxyProvider {
  /// The user agent to use when creating the [Client].
  ///
  /// The default user agent will be used if this is `null`.
  String? get userAgent => null;

  @protected
  late final client = userAgent == null
      ? Client()
      : IOClient(HttpClient()..userAgent = userAgent);

  @override
  @mustCallSuper
  void dispose() {
    client.close();
    super.dispose();
  }
}

/// Providers should throw this if there's a network error.
class ProxyProviderNetworkException implements Exception {
  const ProxyProviderNetworkException();
}

/// Providers should throw this if there's an authentication error while
/// generating the proxy.
class ProxyProviderAuthenticationException implements Exception {
  const ProxyProviderAuthenticationException();
}

/// Providers should throw this if no proxies are found.
class ProxyProviderNoProxiesFoundException implements Exception {
  const ProxyProviderNoProxiesFoundException();
}

/// Providers should throw this if there's an error specific to generating
/// their proxy.
class ProxyProviderSpecificException implements Exception {
  final String message;

  const ProxyProviderSpecificException(this.message);

  @override
  String toString() => 'ProxyProviderSpecificException: $message';
}
