# AWS IoT SigV4

A Flutter package for connecting to AWS IoT Core using SigV4 signed cognito / temporary credentials.

## Features

- Connect to AWS IoT Core using temporary AWS credentials (STS)
- SigV4 signing for secure WebSocket connections
- MQTT client integration for real-time telemetry
- Automatic topic subscription based on allowed device IDs
- Stream-based message handling

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  aws_iot_sigv4:
    path: ../packages/aws_iot_sigv4
```

Or if published to pub.dev:

```yaml
dependencies:
  aws_iot_sigv4: ^1.0.0
```

## Usage

### 1. Get Credentials from Your Backend

First, you need to get temporary AWS credentials from your backend:

```dart
import 'package:aws_iot_sigv4/aws_iot_sigv4.dart';

final service = AwsIotService(baseUrl: 'https://your-backend.com');
final credentials = await service.getCredentials(accessToken);
```

### 2. Connect and Subscribe

```dart
// Connect and get a stream of telemetry data
final stream = service.connectAndSubscribe(credentials);

// Listen to messages
stream.listen((data) {
  if (data.containsKey('error')) {
    print('Error: ${data['error']}');
  } else {
    print('Received: $data');
  }
});
```

### 3. Disconnect

```dart
await service.disconnect();
```

## API Reference

### AwsIotService

Main service class for managing AWS IoT connections.

#### Methods

- `getCredentials(String accessToken)`: Fetch temporary credentials from backend
- `connectAndSubscribe(AwsIotCredentials credentials)`: Connect to AWS IoT and subscribe to topics
- `disconnect()`: Disconnect from AWS IoT

### AwsIotDevice

Low-level device class for direct MQTT connections.

#### Methods

- `connect(String clientId)`: Connect to AWS IoT Core
- `subscribe(String topic, [MqttQos qosLevel])`: Subscribe to a topic
- `publishMessage(String topic, String payload)`: Publish a message
- `disconnect()`: Disconnect from AWS IoT

### AwsIotCredentials

Model for AWS IoT temporary credentials.

#### Properties

- `accessKeyId`: AWS access key ID
- `secretAccessKey`: AWS secret access key
- `sessionToken`: AWS session token
- `expiration`: Token expiration time
- `iotEndpoint`: AWS IoT endpoint URL
- `region`: AWS region
- `allowedDeviceIds`: List of allowed device IDs

## License

MIT

