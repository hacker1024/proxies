import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart';
import 'package:meta/meta.dart';
import 'package:proxies/src/proxy.dart';
import 'package:proxies/src/proxy_provider.dart';

class VpnUnlimitedProxyProvider extends AuthenticatedProxyProvider {
  // The hardcoded '2' in the HTTP headers comes from the end of this.
  // static const _sdkApplicationId = 'com.simplexsolutionsinc.vpnguard.2';

  // This is used for generating a header. A hardcoded array of UTF-8 bytes is
  // used in this implementation, declared at the bottom of this class.
  // static const _sdkApplicationSecret =
  //     'qYnVYF8QbFipfpnsH8W6NYc1GIDOcDTSGLzDj7PK';

  static const _encoder = Utf8Encoder();
  static final _hmacSha1 = Hmac(sha1, _sdkApplicationSecret);

  static final _authUri = Uri(
    scheme: 'https',
    host: 'auth.simplexsolutionsinc.com',
    path: 'api/v1',
  );

  static final _apiUri =
      Uri(scheme: 'https', host: 'api.vpnunlimitedapp.com', path: 'api/v1');

  static Client _clientField;

  static Client get _client => _clientField ??= _buildClient();

  String _region;

  final String _deviceId;
  final bool _isGuest;

  String _accessToken;
  String _session;

  /// Creates the provider, using the given region.
  /// The default parameters are the guest account login.
  VpnUnlimitedProxyProvider.withRegion({
    @required String username,
    @required String password,
    @required String region,
    String deviceId,
  })  : _isGuest = false,
        assert(username != null),
        assert(password != null),
        assert(region != null && region.isNotEmpty),
        _region = region,
        _deviceId = deviceId ?? _generateDeviceId(),
        super(username, password);

  /// Creates the provider, using the given server group.
  /// The default parameters are the guest account login.
  VpnUnlimitedProxyProvider.withServerGroup({
    @required String username,
    @required String password,
    @required VpnUnlimitedServerGroup serverGroup,
  }) : this.withRegion(
          username: username,
          password: password,
          region: serverGroup.region,
        );

  /// Creates the provider, using the given region.
  /// Uses guest credentials.
  /// The default parameters are the guest account login.
  VpnUnlimitedProxyProvider.guestWithRegion({
    @required VpnUnlimitedGuestCredentials credentials,
    @required String region,
  })  : _isGuest = true,
        assert(credentials != null),
        assert(region != null && region.isNotEmpty),
        _region = region,
        _deviceId = credentials._deviceId,
        super(credentials._username, credentials._password);

  /// Creates the provider, using the given region.
  /// Uses guest credentials.
  /// The default parameters are the guest account login.
  VpnUnlimitedProxyProvider.guestWithServerGroup({
    @required VpnUnlimitedGuestCredentials credentials,
    @required VpnUnlimitedServerGroup serverGroup,
  }) : this.guestWithRegion(
          credentials: credentials,
          region: serverGroup.region,
        );

  /// Sets the region from a region string.
  void setRegion(String region) {
    _region = region;
  }

  /// Sets the region from a server group.
  void setServerGroup(VpnUnlimitedServerGroup serverGroup) {
    _region = serverGroup.region;
  }

  @override
  Future<Proxy> getProxy() async {
    if (_session == null) await _login();
    final proxyJson = (await _makeApiRequest(
      _apiUri,
      'configinfo',
      {
        'protocol': 'https_proxy',
        'region': _region,
      },
    ))['config'];

    return Proxy(
      host: proxyJson['domains'].first['domain'],
      port: proxyJson['endpoints'].first['port'],
      username: proxyJson['username'],
      password: proxyJson['password'],
    );
  }

  @override
  Future<void> invalidateCaches() async {}

  static Client _buildClient() => ProxyProvider.buildClient(
        'Dalvik/2.1.0 (Linux; U; Android 11; Pixel 4 XL Build/RP1A.200720.009)',
      );

  /// Returns a list of [VpnUnlimitedServerGroup]s.
  static Future<List<VpnUnlimitedServerGroup>> getServerGroups() async {
    // if (_session == null) await _login();
    final serverGroupListJson = (await _makeApiRequestStatic(
      _apiUri,
      'vpnservers',
    ))['servers'];

    return [
      for (final serverGroupJson in serverGroupListJson)
        VpnUnlimitedServerGroup._fromJson(serverGroupJson),
    ];
  }

  static String _generateDeviceId([Random random]) {
    final randomGenerator = random ?? Random();
    return randomGenerator.nextInt(1 << 32).toRadixString(16) +
        randomGenerator.nextInt(1 << 32).toRadixString(16);
  }

  static String _getAuthorizationString(List<int> requestData) {
    return hex.encode(_hmacSha1.convert(requestData).bytes);
  }

  static Future<Map<String, dynamic>> _makeApiRequestStatic(
    Uri uri,
    String action, [
    Map<String, dynamic> requestData = const {},
    String deviceId,
    String accessToken,
    String session,
  ]) async {
    final requestBytes = _encoder.convert(jsonEncode({
      'action': action,
      if (session != null) 'session': session,
      'appversion': '8.0.4', // The Android app version.
      'deviceid': deviceId ?? '1a2b3c4d1a2b3c4d',
      'platform': 'Android', // The OS.
      'service': 'com.simplexsolutionsinc.vpnguard',
      'platformversion': '11', // The Android version.
      'device': 'Pixel 4 XL', // Usually a specific model name.
      ...requestData,
    }));

    try {
      return jsonDecode(
        (await _client.put(
          uri,
          body: requestBytes,
          headers: {
            'X-KeepSolid-ApplicationId': '2',
            'X-KeepSolid-Authorization': _getAuthorizationString(requestBytes),
            if (accessToken != null) 'X-KS-ACCESS-TOKEN': accessToken,
          },
        ))
            .body,
      );
    } on SocketException {
      throw ProxyProviderNetworkException();
    }
  }

  Future<Map<String, dynamic>> _makeApiRequest(
    Uri uri,
    String action, [
    Map<String, dynamic> requestData = const {},
  ]) async {
    final response = await _makeApiRequestStatic(
      uri,
      action,
      requestData,
      _deviceId,
      _accessToken,
      _session,
    );

    if (response.containsKey('response')) {
      switch (response['response']) {
        case 503:
          throw ProxyProviderAuthenticationException();
          break;
        case 302:
          if (!_isGuest) throw ProxyProviderAuthenticationException();
          throw ProxyProviderSpecificException('302');
      }
    }

    return response;
  }

  Future<void> _login() async {
    Map<String, dynamic> loginResponse;

    Future<void> login() async {
      loginResponse = await _makeApiRequest(
        _authUri,
        'login_v2',
        {
          'login': username,
          'password': password,
        },
      );
    }

    try {
      await login();
    } on ProxyProviderSpecificException catch (e) {
      if (e.message != '302') rethrow;

      try {
        await _registerGuest();
        await login();
      } on SocketException {
        throw ProxyProviderNetworkException();
      }
    }

    _accessToken = loginResponse['access_token'];
    _session = loginResponse['session'];
  }

  Future<void> _registerGuest() async {
    await _makeApiRequest(
      _authUri,
      'newapple',
      {
        'login': username,
        'password': password,
      },
    );
  }

  static const _sdkApplicationSecret = [
    113,
    89,
    110,
    86,
    89,
    70,
    56,
    81,
    98,
    70,
    105,
    112,
    102,
    112,
    110,
    115,
    72,
    56,
    87,
    54,
    78,
    89,
    99,
    49,
    71,
    73,
    68,
    79,
    99,
    68,
    84,
    83,
    71,
    76,
    122,
    68,
    106,
    55,
    80,
    75,
  ];
}

/// This class can generate some guest credentials, which last for 6 days with a
/// trial status.
class VpnUnlimitedGuestCredentials {
  static const _guestUsernamePrefix = 'newapple';
  static const _guestUsernameSuffix = '@keepsolid.com';

  final String _username;
  final String _password;

  String get _deviceId => _password;

  VpnUnlimitedGuestCredentials._(String deviceId)
      : _username = _guestUsernamePrefix + deviceId + _guestUsernameSuffix,
        _password = deviceId;

  VpnUnlimitedGuestCredentials([Random random])
      : this._(VpnUnlimitedProxyProvider._generateDeviceId(random));

  @override
  bool operator ==(Object other) =>
      other is VpnUnlimitedGuestCredentials && other._password == _password;

  @override
  int get hashCode => _password.hashCode;
}

/// A class representing a VPN Unlimited server that can be used to generate
/// a proxy.
class VpnUnlimitedServerGroup {
  final String region;
  final String domain;
  final String name;
  final String description;
  final int priority;
  final String countryCode;
  final bool p2pRestricted;
  final bool isHealthy;
  final String latitude;
  final String longitude;
  final double networkLoadCurrent;
  final double networkLoadAverage;
  final double networkLoadNormalized;
  final int serversHealth;
  final bool isFree;
  final String flagHttp1xUrl;
  final String flagHttp2xUrl;
  final String flagHttps1xUrl;
  final String flagHttps2xUrl;

  VpnUnlimitedServerGroup._fromJson(Map<String, dynamic> json)
      : region = json['region'],
        domain = json['domain'],
        name = json['name'],
        description = json['description'],
        priority = json['priority'],
        countryCode = json['country_code'],
        p2pRestricted = json['p2p_restricted'],
        isHealthy = json['is_healthy'],
        latitude = json['latitude'],
        longitude = json['longitude'],
        networkLoadCurrent = double.parse(json['network_load_current']),
        networkLoadAverage = double.parse(json['network_load_average']),
        networkLoadNormalized = double.parse(json['network_load_normalized']),
        serversHealth = int.parse(json['servers_health']),
        isFree = json['free'],
        flagHttp1xUrl = json['flag_http_1x'],
        flagHttp2xUrl = json['flag_http_2x'],
        flagHttps1xUrl = json['flag_https_1x'],
        flagHttps2xUrl = json['flag_https_2x'];

  @override
  String toString() {
    return 'VPN Unlimited Server Group - name: $name, region: $region, domain: $domain';
  }
}
