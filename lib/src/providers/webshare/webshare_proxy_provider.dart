import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:proxies/src/proxy.dart';
import 'package:proxies/src/proxy_provider.dart';

class WebshareProxyProvider extends ProxyProvider {
  /// You API key, created at https://proxy.webshare.io/userapi/keys.
  String apiKey;

  /// The preferred country code of the retrieved proxy. If left out, or
  /// invalid, no specific country is guaranteed.
  String countryCode;

  /// The prioritization to use when choosing a proxy.
  WebshareProxyPrioritization prioritization;

  WebshareProxyProvider({
    @required this.apiKey,
    this.countryCode,
    this.prioritization = WebshareProxyPrioritization.mostRecentVerification,
  }) : assert(apiKey != null);

  final _client = ProxyProvider.buildClient();

  Uri get _proxyListUri => Uri(
        scheme: 'https',
        host: 'proxy.webshare.io',
        path: 'api/proxy/list',
      );

  @override
  Future<Proxy> getProxy() async => (await getProxies())
      .firstWhere((webshareProxy) => webshareProxy.isValid)
      .toProxy();

  @override
  Future<void> invalidateCaches() async {}

  /// Retreives a list of proxies from the Webshare API.
  Future<List<WebshareProxy>> getProxies() async {
    try {
      final response = await _client.get(
        _proxyListUri.replace(queryParameters: {'countries': countryCode}),
        headers: {HttpHeaders.authorizationHeader: 'Token $apiKey'},
      );

      if (response.statusCode == HttpStatus.unauthorized) {
        throw const ProxyProviderAuthenticationException();
      }

      final List<dynamic> proxiesJson = jsonDecode(response.body)['results'];
      if (proxiesJson.isEmpty) {
        throw const ProxyProviderNoProxiesFoundException();
      }

      final proxies = [
        for (final proxyJson in proxiesJson) WebshareProxy.fromJson(proxyJson),
      ];

      switch (prioritization) {
        case WebshareProxyPrioritization.mostRecentVerification:
          proxies.sort(
            (a, b) => a.lastVerification.compareTo(b.lastVerification),
          );
          break;
        case WebshareProxyPrioritization.highestCountryCodeConfidence:
          proxies.sort(
            (a, b) =>
                a.countryCodeConfidence.compareTo(b.countryCodeConfidence),
          );
          break;
      }

      return proxies;
    } on SocketException {
      throw const ProxyProviderNetworkException();
    }
  }
}

enum WebshareProxyPrioritization {
  mostRecentVerification,
  highestCountryCodeConfidence,
}

class WebshareProxy {
  final String username;
  final String password;
  final String address;
  final int port;
  final bool isValid;
  final DateTime lastVerification;
  final String countryCode;
  final double countryCodeConfidence;

  WebshareProxy.fromJson(Map<String, dynamic> json)
      : username = json['username'],
        password = json['password'],
        address = json['proxy_address'],
        port = json['ports']['http'],
        isValid = json['valid'],
        lastVerification = DateTime.parse(json['last_verification']),
        countryCode = json['country_code'],
        countryCodeConfidence = json['country_code_confidence'];

  Proxy toProxy() => Proxy(
        host: address,
        port: port,
        username: username,
        password: password,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebshareProxy &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          password == other.password &&
          address == other.address &&
          port == other.port &&
          isValid == other.isValid &&
          lastVerification == other.lastVerification &&
          countryCode == other.countryCode &&
          countryCodeConfidence == other.countryCodeConfidence;

  @override
  int get hashCode =>
      username.hashCode ^
      password.hashCode ^
      address.hashCode ^
      port.hashCode ^
      isValid.hashCode ^
      lastVerification.hashCode ^
      countryCode.hashCode ^
      countryCodeConfidence.hashCode;
}
