# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial release of terraform-aws-slackbot-lambdalith module
- Support for AWS Lambda-based Slack bot with Bedrock integration
- Three deployment modes: default (template-based), custom directory, and custom zip
- Automatic Lambda layer creation from requirements.txt
- AWS Secrets Manager integration for secure credential storage
- API Gateway HTTP API for webhook endpoint
- CloudWatch logging and X-Ray tracing
- Comprehensive examples and documentation

### Changed
- N/A

### Deprecated
- N/A

### Removed
- N/A

### Fixed
- N/A

### Security
- Secrets stored in AWS Secrets Manager with proper IAM permissions
