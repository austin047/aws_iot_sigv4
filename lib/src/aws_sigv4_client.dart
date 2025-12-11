import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

const _awsSha256 = 'AWS4-HMAC-SHA256';
const _aws4Request = 'aws4_request';
const _aws4 = 'AWS4';
const _xAmzDate = 'x-amz-date';
const _xAmzSecurityToken = 'x-amz-security-token';
const _host = 'host';
const _authorization = 'Authorization';
const _defaultContentType = 'application/json';
const _defaultAcceptType = 'application/json';

class AwsSigV4Client {
  late String endpoint;
  late String pathComponent;
  String region;
  String accessKey;
  String secretKey;
  String sessionToken;
  String serviceName;
  String defaultContentType;
  String defaultAcceptType;
  AwsSigV4Client(
    this.accessKey,
    this.secretKey,
    String endpoint, {
    this.serviceName = 'execute-api',
    this.region = 'us-east-1',
    required this.sessionToken,
    this.defaultContentType = _defaultContentType,
    this.defaultAcceptType = _defaultAcceptType,
  }) {
    final parsedUri = Uri.parse(endpoint);
    this.endpoint = '${parsedUri.scheme}://${parsedUri.host}';
    pathComponent = parsedUri.path;
  }
}

class SigV4Request {
  late String method;
  late String path;
  Map<String, String> queryParams;
  Map<String, String> headers;
  late String url;
  late String body;
  AwsSigV4Client awsSigV4Client;
  late String canonicalRequest;
  late String hashedCanonicalRequest;
  late String credentialScope;
  late String stringToSign;
  String datetime;
  late List<int> signingKey;
  late String signature;
  SigV4Request(
    this.awsSigV4Client, {
    required String method,
    required String path,
    required this.datetime,
    required this.queryParams,
    required this.headers,
    required dynamic body,
  }) {
    this.method = method.toUpperCase();
    this.path = '${awsSigV4Client.pathComponent}$path';

    // Set default headers if not provided
    if (headers['Accept'] == null) {
      headers['Accept'] = awsSigV4Client.defaultAcceptType;
    }

    // Handle body
    if (body == null || this.method == 'GET') {
      this.body = '';
    } else {
      this.body = json.encode(body);
    }

    // Set Content-Type only if body is not empty
    if (this.body.isNotEmpty && headers['Content-Type'] == null) {
      headers['Content-Type'] = awsSigV4Client.defaultContentType;
    }

    // Generate datetime if not provided
    if (datetime.isEmpty) {
      datetime = SigV4.generateDatetime();
    }

    headers[_xAmzDate] = datetime;
    final endpointUri = Uri.parse(awsSigV4Client.endpoint);
    headers[_host] = endpointUri.host;

    headers[_authorization] = _generateAuthorization(datetime);
    if (awsSigV4Client.sessionToken.isNotEmpty) {
      headers[_xAmzSecurityToken] = awsSigV4Client.sessionToken;
    }
    headers.remove(_host);

    url = _generateUrl();
  }

  String _generateUrl() {
    var url = '${awsSigV4Client.endpoint}$path';
    if (queryParams.isNotEmpty) {
      final queryString = SigV4.buildCanonicalQueryString(queryParams);
      if (queryString.isNotEmpty) {
        url += '?$queryString';
      }
    }
    return url;
  }

  String _generateAuthorization(String datetime) {
    canonicalRequest = SigV4.buildCanonicalRequest(
      method,
      path,
      queryParams,
      headers,
      body,
    );
    hashedCanonicalRequest = SigV4.hashCanonicalRequest(canonicalRequest);
    credentialScope = SigV4.buildCredentialScope(
      datetime,
      awsSigV4Client.region,
      awsSigV4Client.serviceName,
    );
    stringToSign = SigV4.buildStringToSign(
      datetime,
      credentialScope,
      hashedCanonicalRequest,
    );
    signingKey = SigV4.calculateSigningKey(
      awsSigV4Client.secretKey,
      datetime,
      awsSigV4Client.region,
      awsSigV4Client.serviceName,
    );
    signature = SigV4.calculateSignature(signingKey, stringToSign);
    return SigV4.buildAuthorizationHeader(
      awsSigV4Client.accessKey,
      credentialScope,
      headers,
      signature,
    );
  }
}

class SigV4 {
  static String generateDatetime() {
    return DateTime.now()
        .toUtc()
        .toString()
        .replaceAll(RegExp(r'\.\d*Z$'), 'Z')
        .replaceAll(RegExp(r'[:-]|\.\d{3}'), '')
        .split(' ')
        .join('T');
  }

  static List<int> hash(List<int> value) {
    return sha256.convert(value).bytes;
  }

  static String hexEncode(List<int> value) {
    return hex.encode(value);
  }

  static List<int> sign(List<int> key, String message) {
    final hmac = Hmac(sha256, key);
    final dig = hmac.convert(utf8.encode(message));
    return dig.bytes;
  }

  static String hashCanonicalRequest(String request) {
    return hexEncode(hash(utf8.encode(request)));
  }

  static String buildCanonicalUri(String uri) {
    return Uri.encodeFull(uri);
  }

  static String buildCanonicalQueryString(Map<String, String> queryParams) {
    if (queryParams.isEmpty) {
      return '';
    }

    final sortedKeys = queryParams.keys.toList()..sort();

    final canonicalQueryStrings = <String>[];
    for (final key in sortedKeys) {
      final value = queryParams[key];
      if (value != null) {
        canonicalQueryStrings.add('$key=${Uri.encodeComponent(value)}');
      }
    }

    return canonicalQueryStrings.join('&');
  }

  static String buildCanonicalHeaders(Map<String, String> headers) {
    final sortedKeys = headers.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final canonicalHeaders = StringBuffer();
    for (final property in sortedKeys) {
      canonicalHeaders.write(
        '${property.toLowerCase()}:${headers[property]}\n',
      );
    }

    return canonicalHeaders.toString();
  }

  static String buildCanonicalSignedHeaders(Map<String, String> headers) {
    final sortedKeys = headers.keys.map((key) => key.toLowerCase()).toList()
      ..sort();

    return sortedKeys.join(';');
  }

  static String buildStringToSign(
    String datetime,
    String credentialScope,
    String hashedCanonicalRequest,
  ) {
    return '$_awsSha256\n$datetime\n$credentialScope\n$hashedCanonicalRequest';
  }

  static String buildCredentialScope(
    String datetime,
    String region,
    String service,
  ) {
    return '${datetime.substring(0, 8)}/$region/$service/$_aws4Request';
  }

  static String buildCanonicalRequest(
    String method,
    String path,
    Map<String, String> queryParams,
    Map<String, String> headers,
    String payload,
  ) {
    final List<String> canonicalRequest = [
      method,
      buildCanonicalUri(path),
      buildCanonicalQueryString(queryParams),
      buildCanonicalHeaders(headers),
      buildCanonicalSignedHeaders(headers),
      hexEncode(hash(utf8.encode(payload))),
    ];
    return canonicalRequest.join('\n');
  }

  static String buildAuthorizationHeader(
    String accessKey,
    String credentialScope,
    Map<String, String> headers,
    String signature,
  ) {
    return '$_awsSha256 Credential=$accessKey/$credentialScope, SignedHeaders=${buildCanonicalSignedHeaders(headers)}, Signature=$signature';
  }

  static List<int> calculateSigningKey(
    String secretKey,
    String datetime,
    String region,
    String service,
  ) {
    return sign(
      sign(
        sign(
          sign(utf8.encode('$_aws4$secretKey'), datetime.substring(0, 8)),
          region,
        ),
        service,
      ),
      _aws4Request,
    );
  }

  static String calculateSignature(List<int> signingKey, String stringToSign) {
    return hexEncode(sign(signingKey, stringToSign));
  }
}
