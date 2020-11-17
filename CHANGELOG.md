## 0.2.0
- When a provider fails to find proxies, it now throws a more specific `ProxyProviderNoProxiesFoundException`.
- Provider changes:
  - NordVPN:
    - Allow changing the country code
  - Webshare:
    - Add support

## 0.1.2
- Provider changes:
  - NordVPN:
    - Don't use URL encoding on credentials

## 0.1.1
- Initial release
- Supported services:
  - Simple
  - NordVPN
