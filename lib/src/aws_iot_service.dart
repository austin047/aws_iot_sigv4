import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'aws_iot_device.dart';
import 'models/aws_iot_credentials.dart';

/// Service class for connecting to AWS IoT Core using temporary credentials
class AwsIotService {
  final String baseUrl;
  AwsIotDevice? _device;
  StreamController<Map<String, dynamic>>? _telemetryController;

  AwsIotService({required this.baseUrl});

  /// Get IoT credentials from backend
  Future<AwsIotCredentials> getCredentials(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/iot/credentials'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        final data = jsonData['data'] as Map<String, dynamic>;
        return AwsIotCredentials.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to get IoT credentials',
        );
      }
    } catch (e) {
      throw Exception('IoT credentials error: $e');
    }
  }

  /// Connect to AWS IoT using temporary credentials
  Stream<Map<String, dynamic>> connectAndSubscribe(
    AwsIotCredentials credentials,
  ) {
    _telemetryController = StreamController<Map<String, dynamic>>.broadcast();

    // Start connection asynchronously
    _connectAsync(credentials);

    return _telemetryController!.stream;
  }

  Future<void> _connectAsync(AwsIotCredentials credentials) async {
    try {
      // Extract hostname from endpoint
      // e.g., "https://a3hnp0canudwcy-ats.iot.eu-west-1.amazonaws.com"
      final endpoint = credentials.iotEndpoint
          .replaceAll('https://', '')
          .replaceAll('http://', '');

      String host;
      if (endpoint.contains('amazonaws.com')) {
        host = endpoint.split('.').first;
      } else {
        host = endpoint;
      }

      // Create AWS IoT Device instance
      _device = AwsIotDevice(
        credentials.region,
        credentials.accessKeyId,
        credentials.secretAccessKey,
        credentials.sessionToken,
        host,
        logging: false,
        onConnected: () {
          _telemetryController?.add({
            'status': 'connected',
            'message': 'Successfully connected to AWS IoT',
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onDisconnected: () {
          _telemetryController?.add({
            'status': 'disconnected',
            'message': 'Disconnected from AWS IoT',
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onSubscribed: (String topic) {
          _telemetryController?.add({
            'status': 'subscribed',
            'topic': topic,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onSubscribeFail: (String topic) {
          _telemetryController?.add({
            'error': 'Failed to subscribe to $topic',
            'topic': topic,
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
      );

      // Connect with a unique client ID
      final clientId = 'flutter-iot-${DateTime.now().millisecondsSinceEpoch}';
      await _device!.connect(clientId);

      // Subscribe to topics for all allowed devices
      for (final deviceId in credentials.allowedDeviceIds) {
        final topic = 'device/$deviceId/telemetry';
        _device!.subscribe(topic);
      }

      // Listen to messages
      _device!.messages.listen(
        (message) {
          final topic = message['topic']!;
          final payload = message['payload']!;

          try {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _telemetryController?.add({
              ...data,
              'topic': topic,
              'timestamp': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            _telemetryController?.add({
              'raw': payload,
              'topic': topic,
              'timestamp': DateTime.now().toIso8601String(),
              'parseError': 'Failed to parse JSON: $e',
            });
          }
        },
        onError: (error) {
          _telemetryController?.add({
            'error': 'Message stream error: $error',
            'timestamp': DateTime.now().toIso8601String(),
          });
        },
        onDone: () {
          // Stream closed
        },
      );
    } catch (e) {
      _telemetryController?.add({
        'error': 'Connection error: $e',
        'timestamp': DateTime.now().toIso8601String(),
      });
      rethrow;
    }
  }

  /// Disconnect from IoT
  Future<void> disconnect() async {
    try {
      _device?.disconnect();
      _device = null;
      await _telemetryController?.close();
      _telemetryController = null;
    } catch (e) {
      // Error disconnecting
    }
  }
}

