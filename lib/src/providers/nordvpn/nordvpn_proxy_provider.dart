import 'dart:convert';
import 'dart:io';

import 'package:proxies/src/proxy.dart';
import 'package:proxies/src/proxy_provider.dart';

/// A provider to use proxies from NordVPN's API.
class NordVPNProxyProvider extends AuthenticatedProxyProvider
    with ProxyProviderClientMixin {
  static const _apiScheme = 'https';
  static const _apiHost = 'api.nordvpn.com';

  String _countryCode;

  /// The country code to use. Must be uppercase.
  /// A full list can be found at https://api.nordvpn.com/v1/servers/countries.
  String get countryCode => _countryCode;

  set countryCode(String newCode) {
    assert(
      newCode.toUpperCase() == newCode,
      'Country code must be in upper case!',
    );
    _countryCode = newCode;
  }

  Map<String, int>? _cachedCountryCodes;

  NordVPNProxyProvider({
    required String username,
    required String password,
    required String countryCode,
  })   : assert(
          countryCode.toUpperCase() == countryCode,
          'Country code must be in upper case!',
        ),
        _countryCode = countryCode,
        super(username, password);

  @override
  Future<Proxy> getProxy() async {
    try {
      if (_cachedCountryCodes == null) await _cacheCountryCodes();
      final servers = await _getServers();
      for (final server in servers) {
        for (Map<String, dynamic> service in server['services']) {
          if (service['identifier'] == 'proxy') {
            return Proxy(
              host: server['hostname'],
              port: 80,
              username: username,
              password: password,
            );
          }
        }
      }

      throw const ProxyProviderNoProxiesFoundException();
    } on SocketException {
      throw const ProxyProviderNetworkException();
    }
  }

  @override
  Future<void> invalidateCaches() async {
    _cachedCountryCodes = null;
  }

  Future<void> _cacheCountryCodes() async {
    final List<dynamic> countriesJson = jsonDecode(
      (await client.read(
        Uri(
          scheme: _apiScheme,
          host: _apiHost,
          path: 'v1/servers/countries',
        ),
      )),
    );

    _cachedCountryCodes = {
      for (final countryListing in countriesJson)
        countryListing['code']: countryListing['id'],
    };
  }

  // An example GET request observed by monitoring the browser extension's
  // network activity:
  // https://api.nordvpn.com/v1/servers/recommendations
  //   ?filters[country_id]=228
  //   &filters[servers_groups][identifier]=legacy_standard
  //   &filters[servers_technologies][identifier]=proxy_ssl
  //   &limit=1
  Future<List<dynamic>> _getServers() async {
    final requestURI = Uri(
      scheme: _apiScheme,
      host: _apiHost,
      path: '/v1/servers/recommendations',
      queryParameters: {
        // The server picker tool at https://nordvpn.com/servers/tools/ appears
        // to grab five and choose the first.
        // The browser extension just grabs one.
        // The results are ordered by load; lowest -> highest.
        'limit': '1',
        // // Not really sure what this does; copied from the Android app.
        // // 'filters[servers_technologies][pivot][status]': 'online',
        'filters[country_id]': _cachedCountryCodes![countryCode].toString(),
        // Selects the HTTP Proxy type.
        'filters[servers_technologies][id]': '9',
        // The following are disabled parameters that request for a HTTPS/SSL
        // proxy. Waiting on https://github.com/dart-lang/sdk/issues/43876.
        // The SSL proxy is on port 89.
        // // Unlike the disabled parameters above, the browser extension selects
        // // the proxy filter a different way.
        // 'filters[servers_groups][identifier]': 'legacy_standard',
        // 'filters[servers_technologies][id]': 'proxy_ssl',
      },
    );

    return jsonDecode((await client.read(requestURI)));
  }
}
