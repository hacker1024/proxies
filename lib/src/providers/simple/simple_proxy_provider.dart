import 'package:proxies/src/proxy.dart';
import 'package:proxies/src/proxy_provider.dart';

/// A simple proxy provider.
/// Uses the provided [host], [port], [username], and [password].
/// [username] and [password] may be null.
class SimpleProxyProvider extends AuthenticatedProxyProvider {
  final String host;
  final int port;

  SimpleProxyProvider(this.host, this.port, String username, String password)
      : super(username, password);

  /// Validates the given hostname.
  ///
  /// Can be useful to use in UIs; this package doesn't use this
  /// function itself.
  ///
  /// Returns null if there are no problems, or a description [String]
  /// otherwise.
  String? validateHost(String host) {
    String? validateHostnameOrIP(String host) {
      // Thanks to these RegEx gods: https://stackoverflow.com/questions/106179/regular-expression-to-match-dns-hostname-or-ip-address
      // Note: must confirm this is RegEx and not an ancient alien language, because I can't tell the difference ATM.
      if (!RegExp(r'^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$')
              .hasMatch(host) &&
          !RegExp(r'(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)){3}')
              .hasMatch(host)) {
        return 'Host is not valid.';
      }
      return null;
    }

    if (host.isEmpty) {
      return 'No host given.';
    }

    if (host.contains('@') || host.contains(':')) {
      return 'Invalid characters in hostname';
    }

    return validateHostnameOrIP(host);
  }

  /// Validates the given port string.
  ///
  /// See [validateHost] for return values.
  String? validatePort(String port) {
    if (port.isEmpty) return 'No port given.';
    final parsedPort = int.tryParse(port);
    if (parsedPort == null) return 'Invalid port.';
    if (parsedPort.isNegative) return 'Port must be positive.';
    if (parsedPort == 0) return 'Port cannot be zero.';
    return null;
  }

  @override
  String? validateUsername(String username) => null;

  @override
  String? validatePassword(String password) => null;

  @override
  Future<Proxy> getProxy() async {
    return Proxy(
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }

  @override
  Future<void> invalidateCaches() async {
    // N/A, no network operations are done by this provider.
  }
}
