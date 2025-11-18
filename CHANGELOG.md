# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2025-06-29

### Fixed
- Fixed authentication flow where successful authentication was terminating requests instead of allowing content access
- Removed `ngx.exit(ngx.OK)` after successful authentication to properly allow requests to continue

## [1.0.0] - 2025-06-29

### Added
- Initial release
- RFC 2617 compliant HTTP Digest Authentication
- Brute force protection with configurable thresholds
- Rate limiting with per-client tracking
- Suspicious pattern detection (empty credentials, malformed headers, rapid requests)
- Username enumeration protection
- Nonce management with configurable reuse limits
- Shared memory support for cross-worker communication
- Docker-based test suite
- GitHub Actions CI/CD pipeline
