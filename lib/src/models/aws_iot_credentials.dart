/// Model for AWS IoT temporary credentials
class AwsIotCredentials {
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final String expiration;
  final String iotEndpoint;
  final String region;
  final List<String> allowedDeviceIds;

  /// Optional MQTT client ID assigned by the credentials issuer. When set, the
  /// backend's session policy is expected to scope `iot:Connect` to this exact
  /// client ID, so the value from the server MUST be used verbatim. If null,
  /// the package falls back to an auto-generated client ID.
  final String? clientId;

  AwsIotCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
    required this.expiration,
    required this.iotEndpoint,
    required this.region,
    required this.allowedDeviceIds,
    this.clientId,
  });

  factory AwsIotCredentials.fromJson(Map<String, dynamic> json) {
    return AwsIotCredentials(
      accessKeyId: json['accessKeyId'] as String,
      secretAccessKey: json['secretAccessKey'] as String,
      sessionToken: json['sessionToken'] as String,
      expiration: json['expiration'] as String,
      iotEndpoint: json['iotEndpoint'] as String,
      region: json['region'] as String,
      allowedDeviceIds: List<String>.from(json['allowedDeviceIds'] as List),
      clientId: json['clientId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessKeyId': accessKeyId,
      'secretAccessKey': secretAccessKey,
      'sessionToken': sessionToken,
      'expiration': expiration,
      'iotEndpoint': iotEndpoint,
      'region': region,
      'allowedDeviceIds': allowedDeviceIds,
      if (clientId != null) 'clientId': clientId,
    };
  }
}
