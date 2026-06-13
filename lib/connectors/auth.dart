/// Supplies an OAuth access token to a connector.
///
/// This keeps token *acquisition* (provider- and platform-specific OAuth — see
/// CONNECT_SETUP.md) separate from the REST calls, so the connectors stay
/// simple, real, and testable. Swap in a full OAuth implementation later
/// without touching the connectors.
abstract class TokenSource {
  Future<String> token();
}

/// Holds a token you paste in (e.g. from Microsoft Graph Explorer or Google's
/// OAuth 2.0 Playground). Perfect for verifying the real connectors before you
/// wire up the full OAuth login flow. Tokens are short-lived, so expect to
/// refresh it during testing.
class StaticTokenSource implements TokenSource {
  String value;
  StaticTokenSource(this.value);

  @override
  Future<String> token() async {
    if (value.trim().isEmpty) {
      throw StateError('No access token set for this connector.');
    }
    return value.trim();
  }
}
