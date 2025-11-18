# Changelog

All notable changes to this project will be documented in this file.

## [1.0.3] - 2025-11-18

### Fixed
- Fixed `get_keys()` API calls in `clear_nonces()` and `cleanup_expired_nonces()` functions
- Fixed incorrect credential hash for bob test user
- Fixed memory clearing between test runs to prevent false brute force blocks

### Added
- Comprehensive test suites (advanced, memory management, brute force)
- StyLua code formatter with pre-commit hooks
- Admin endpoints for testing memory cleanup functions
- Nonce lifecycle and edge case testing
- QOP parameter validation tests
- Header injection protection tests
- Performance testing under concurrent load

### Changed
- Enabled brute force protection in test environment
- Renamed test scripts for consistency (removed test_ prefix)
- Updated all documentation examples to use --digest flag correctly
- Integrated StyLua linting in CI/CD pipeline
- Improved test isolation and reliability

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
