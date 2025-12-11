# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-01-10

### Added
- Initial release
- `AwsIotService` - Main service class for connecting to AWS IoT Core
- `AwsIotDevice` - Low-level device class for MQTT connections
- `AwsIotCredentials` - Model for AWS IoT temporary credentials
- SigV4 signing implementation for secure WebSocket connections
- Automatic topic subscription based on allowed device IDs
- Stream-based message handling

