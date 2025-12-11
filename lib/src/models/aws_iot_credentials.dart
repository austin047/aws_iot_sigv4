/// Model for AWS IoT temporary credentials
class AwsIotCredentials {
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;
  final String expiration;
  final String iotEndpoint;
  final String region;
  final List<String> allowedDeviceIds;

  AwsIotCredentials({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
    required this.expiration,
    required this.iotEndpoint,
    required this.region,
    required this.allowedDeviceIds,
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
    };
  }
}
