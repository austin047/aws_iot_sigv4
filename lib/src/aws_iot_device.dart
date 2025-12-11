import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'aws_sigv4_client.dart';

/// AWS IoT Device class for connecting to AWS IoT Core using SigV4 signed credentials
class AwsIotDevice {
  final String _serviceName = 'iotdevicegateway';
  final String _aws4Request = 'aws4_request';
  final String _aws4HmacSha256 = 'AWS4-HMAC-SHA256';
  final String _scheme = 'wss://';

  final String _region;
  final String _accessKeyId;
  final String _secretAccessKey;
  final String _sessionToken;
  late String _host;
  bool _logging = false;

  Function()? _onConnected;
  Function()? _onDisconnected;
  Function(String)? _onSubscribed;
  Function(String)? _onSubscribeFail;
  Function(String)? onUnsubscribed;

  Function()? get onConnected => _onConnected;
  set onConnected(Function()? val) {
    _onConnected = val;
    _client?.onConnected = val;
  }

  Function()? get onDisconnected => _onDisconnected;
  set onDisconnected(Function()? val) {
    _onDisconnected = val;
    _client?.onDisconnected = val;
  }

  Function(String)? get onSubscribed => _onSubscribed;
  set onSubscribed(Function(String)? val) {
    _onSubscribed = val;
    _client?.onSubscribed = val;
  }

  Function(String)? get onSubscribeFail => _onSubscribeFail;
  set onSubscribeFail(Function(String)? val) {
    _onSubscribeFail = val;
    _client?.onSubscribeFail = val;
  }

  dynamic get connectionStatus => _client?.connectionStatus;

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>?
  _updatesSubscription;

  final StreamController<Map<String, String>> _messagesController =
      StreamController<Map<String, String>>.broadcast();

  Stream<Map<String, String>> get messages => _messagesController.stream;

  AwsIotDevice(
    this._region,
    this._accessKeyId,
    this._secretAccessKey,
    this._sessionToken,
    String host, {
    bool logging = false,
    Function()? onConnected,
    Function()? onDisconnected,
    Function(String)? onSubscribed,
    Function(String)? onSubscribeFail,
    this.onUnsubscribed,
  }) {
    _logging = logging;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    _onSubscribed = onSubscribed;
    _onSubscribeFail = onSubscribeFail;

    if (host.contains('amazonaws.com')) {
      _host = host.split('.').first;
    } else {
      _host = host;
    }
  }

  Future<void> connect(String clientId) async {
    if (_client == null) {
      _prepare(clientId);
    }

    // Check if already connected
    if (_client!.connectionStatus?.state == MqttConnectionState.connected) {
      return;
    }

    try {
      await _client!.connect();
    } on Exception {
      _client?.disconnect();
      _updatesSubscription?.cancel();
      _updatesSubscription = null;
      rethrow;
    }

    // Set up message listener only once
    if (_updatesSubscription == null && _client!.updates != null) {
      _updatesSubscription = _client!.updates!.listen(
        (List<MqttReceivedMessage<MqttMessage>> c) {
          if (_messagesController.isClosed) return;
          for (MqttReceivedMessage<MqttMessage> message in c) {
            final payload = message.payload;
            if (payload is MqttPublishMessage) {
              final String pt = MqttPublishPayload.bytesToStringAsString(
                payload.payload.message,
              );
              if (!_messagesController.isClosed) {
                _messagesController.add({
                  'topic': message.topic,
                  'payload': pt,
                });
              }
            }
          }
        },
        onError: (error) {
          // Error handling
        },
        onDone: () {
          _updatesSubscription = null;
        },
      );
    }
  }

  void _prepare(String clientId) {
    final url = _prepareWebSocketUrl();
    _client = MqttServerClient(url, clientId);
    _client!.logging(on: _logging);
    _client!.useWebSocket = true;
    _client!.port = 443;
    _client!.keepAlivePeriod = 300;
    _client!.connectionMessage = MqttConnectMessage().withClientIdentifier(
      clientId,
    );

    if (_onConnected != null) {
      _client!.onConnected = _onConnected;
    }
    if (_onSubscribeFail != null) {
      _client!.onSubscribeFail = _onSubscribeFail;
    }
    if (_onSubscribed != null) {
      _client!.onSubscribed = _onSubscribed;
    }
    if (_onDisconnected != null) {
      _client!.onDisconnected = _onDisconnected;
    }
  }

  String _prepareWebSocketUrl() {
    if (_region.isEmpty) {
      throw Exception('Invalid region');
    }
    if (_accessKeyId.isEmpty) {
      throw Exception('Invalid accessKeyId');
    }
    if (_secretAccessKey.isEmpty) {
      throw Exception('Invalid secretAccessKey');
    }
    if (_sessionToken.isEmpty) {
      throw Exception('Invalid sessionToken');
    }
    if (_host.isEmpty) {
      throw Exception('Invalid host');
    }

    final now = SigV4.generateDatetime();
    final hostname = _buildHostname();

    final List<String> creds = [
      _accessKeyId,
      _getDate(now),
      _region,
      _serviceName,
      _aws4Request,
    ];

    const payload = '';
    const path = '/mqtt';

    final queryParams = <String, String>{
      'X-Amz-Algorithm': _aws4HmacSha256,
      'X-Amz-Credential': creds.join('/'),
      'X-Amz-Date': now,
      'X-Amz-SignedHeaders': 'host',
    };

    final canonicalQueryString = SigV4.buildCanonicalQueryString(queryParams);
    final request = SigV4.buildCanonicalRequest(
      'GET',
      path,
      queryParams,
      <String, String>{'host': hostname},
      payload,
    );

    final hashedCanonicalRequest = SigV4.hashCanonicalRequest(request);
    final stringToSign = SigV4.buildStringToSign(
      now,
      SigV4.buildCredentialScope(now, _region, _serviceName),
      hashedCanonicalRequest,
    );

    final signingKey = SigV4.calculateSigningKey(
      _secretAccessKey,
      now,
      _region,
      _serviceName,
    );

    final signature = SigV4.calculateSignature(signingKey, stringToSign);

    final finalParams =
        '$canonicalQueryString&X-Amz-Signature=$signature&X-Amz-Security-Token=${Uri.encodeComponent(_sessionToken)}';

    return '$_scheme$hostname$path?$finalParams';
  }

  String _getDate(String dateTime) {
    return dateTime.substring(0, 8);
  }

  String _buildHostname() {
    return '$_host.iot.$_region.amazonaws.com';
  }

  void publishMessage(String topic, String payload) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    final payloadBytes = builder.payload;
    if (payloadBytes != null) {
      _client?.publishMessage(topic, MqttQos.atMostOnce, payloadBytes);
    }
  }

  void disconnect() {
    _updatesSubscription?.cancel();
    _updatesSubscription = null;
    _client?.disconnect();
    if (!_messagesController.isClosed) {
      _messagesController.close();
    }
  }

  Subscription? subscribe(
    String topic, [
    MqttQos qosLevel = MqttQos.atMostOnce,
  ]) {
    return _client?.subscribe(topic, qosLevel);
  }

  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
  }
}
