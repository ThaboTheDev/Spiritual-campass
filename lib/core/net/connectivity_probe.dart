import 'dart:async';
import 'dart:io';

/// A tiny reachability probe, used to explain why the map has no tiles.
///
/// The compass, the sun and the guide all work offline, so the app only needs to
/// know whether the *internet* is reachable for map tiles — not whether a radio
/// is on. A DNS lookup with a short timeout answers that without pulling in a
/// connectivity plugin, and it works on both iOS and Android.
class ConnectivityProbe {
  ConnectivityProbe({
    this.host = 'tile.openstreetmap.org',
    this.timeout = const Duration(seconds: 4),
  });

  /// The host used for the probe: the tile server the map actually needs.
  final String host;

  /// How long to wait before deciding we are offline.
  final Duration timeout;

  /// `true` when the last probe reached the internet.
  bool get isOnline => _isOnline;

  bool _isOnline = false;
  bool _inFlight = false;
  final StreamController<bool> _controller =
      StreamController<bool>.broadcast();

  /// Emits `true` / `false` whenever the reachability result changes.
  Stream<bool> get onChanged => _controller.stream;

  /// Performs a single probe and returns whether the internet is reachable.
  Future<bool> check() async {
    if (_inFlight) {
      return _isOnline;
    }
    _inFlight = true;
    bool result = false;
    try {
      final List<InternetAddress> addresses =
          await InternetAddress.lookup(host).timeout(timeout);
      result = addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty;
    } on SocketException {
      result = false;
    } on TimeoutException {
      result = false;
    } on ArgumentError {
      result = false;
    } catch (_) {
      result = false;
    }
    _inFlight = false;
    _setOnline(result);
    return result;
  }

  void _setOnline(bool value) {
    if (value == _isOnline) {
      return;
    }
    _isOnline = value;
    if (!_controller.isClosed) {
      _controller.add(value);
    }
  }

  /// Releases the broadcast stream, e.g. when the provider is disposed.
  void dispose() {
    _controller.close();
  }
}
