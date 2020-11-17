# Proxies
A Dart package containing a collection of proxy API wrappers.

This package connects to different proxy services' APIs to create an IOClient
that uses the proxy.

## Supported proxy services
There aren't many at the moment - pull requests are welcome!
See the "Extending" section of this README if you'd like to contribute.
- Simple (host, port, username, password)
- [NordVPN](https://nordvpn.com) (requires a paid account)
- [Webshare](https://webshare.io) (requires a [free API key](https://proxy.webshare.io/userapi/keys))

## Usage

To use a proxy provider (read on to create one):
```dart
import 'dart:io';
import 'package:proxies/proxies.dart';

// Get a "Proxy" object from the provider (async because some providers fetch data from a server).
final proxy = await proxyProvider.getProxy();

// Create an IOClient from the Proxy
final client = proxy.createIOClient();

// Use the IOClient
final myHttpRequest = client.get('example.com');
```

To create a regular proxy provider with authentication:

```dart
final proxyProvider = SimpleProxyProvider('host.com', 8080, 'myUsername', 'myPassword');
```

To create a NordVPN proxy provider:
```dart
final proxyProvider = NordVPNProxyProvider(
  username: r'myUsername',
  password: r'myPassword',
  countryCode: 'US',
);
```

Other providers are created in similar ways.

## Extending
Adding a proxy provider is fairly straightforward. The base class to extend
requires these functions to be implemented:

```dart
/// This class defines functions all proxy providers must implement.
abstract class ProxyProvider {
  /// Returns a [Proxy] object future, to be used for necessary network operations.
  Future<Proxy> getProxy();

  /// If the proxy provider caches lists of available proxies, invalidate those caches.
  Future<void> invalidateCaches();
}
```

There's also an `AuthenticatedProxyProvider` that contains a few more
authentication-related things, which should be extended for any authentication-based services.

Take a look in `src/providers/nordvpn/` for an example of the implementation and
directory structure.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/hacker1024/proxies/issues
