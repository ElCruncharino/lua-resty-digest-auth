# Contributing to lua-resty-digest-auth

Thank you for your interest in contributing to lua-resty-digest-auth! This document provides guidelines and information for contributors.

## 🚀 Getting Started

### Prerequisites

- OpenResty 1.19.9+ or Nginx with LuaJIT support
- Docker (for testing)
- Git
- Basic knowledge of Lua and Nginx configuration

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/ElCruncharino/lua-resty-digest-auth.git
   cd lua-resty-digest-auth
   ```

2. **Install Dependencies**
   ```bash
   # For testing
   cd test
   docker-compose up --build
   ```

3. **Run Tests**
   ```bash
   # Basic tests
   docker exec lua-resty-digest-auth-test /usr/local/bin/test_digest_auth
   
   # Production readiness tests
   docker cp test_production_ready.sh lua-resty-digest-auth-test:/tmp/
   docker exec lua-resty-digest-auth-test bash -c 'chmod +x /tmp/test_production_ready.sh && /tmp/test_production_ready.sh'
   ```

## 📝 Development Guidelines

### Code Style

- Follow Lua style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and small
- Use consistent indentation (2 spaces)

### Security Considerations

- All security features must be tested thoroughly
- Brute force protection should be enabled by default
- Rate limiting should be configurable
- Logging should not expose sensitive information
- Input validation should be comprehensive

### Testing Requirements

- All new features must include tests
- Security features must be tested for bypass attempts
- Performance impact should be measured
- Edge cases should be covered
- Documentation should be updated

## 🔧 Making Changes

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

- Implement your feature or fix
- Add tests for new functionality
- Update documentation if needed
- Ensure all tests pass

### 3. Test Your Changes

```bash
# Run the test suite
cd test
docker-compose down && docker-compose up --build -d

# Run basic tests
docker exec lua-resty-digest-auth-test /usr/local/bin/test_digest_auth

# Run production tests
docker cp test_production_ready.sh lua-resty-digest-auth-test:/tmp/
docker exec lua-resty-digest-auth-test bash -c 'chmod +x /tmp/test_production_ready.sh && /tmp/test_production_ready.sh'
```

### 4. Update Documentation

- Update README.md if adding new features
- Update API documentation
- Add examples if applicable
- Update CHANGELOG.md

### 5. Commit Your Changes

```bash
git add .
git commit -m "feat: add new security feature

- Added new brute force detection
- Updated documentation
- Added comprehensive tests"
```

### 6. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## 🧪 Testing Guidelines

### Test Categories

1. **Unit Tests**: Test individual functions
2. **Integration Tests**: Test module integration
3. **Security Tests**: Test security features
4. **Performance Tests**: Test performance impact
5. **Edge Case Tests**: Test unusual scenarios

### Running Tests

```bash
# All tests
cd test
docker-compose up --build -d
./run_all_tests.sh

# Specific test categories
docker exec lua-resty-digest-auth-test /usr/local/bin/test_digest_auth
docker exec lua-resty-digest-auth-test bash -c '/tmp/test_production_ready.sh'
```

### Test Requirements

- All tests must pass before submitting PR
- New features must include tests
- Security features must be thoroughly tested
- Performance impact should be measured

## 📚 Documentation Guidelines

### README Updates

- Keep installation instructions clear
- Update examples for new features
- Maintain consistent formatting
- Include security considerations

### API Documentation

- Document all public functions
- Include parameter descriptions
- Provide usage examples
- Document return values

### Code Comments

- Comment complex logic
- Explain security decisions
- Document configuration options
- Include usage examples in comments

## 🔒 Security Guidelines

### Security Review Process

1. **Code Review**: All changes reviewed for security issues
2. **Testing**: Security features tested for bypass attempts
3. **Documentation**: Security considerations documented
4. **Validation**: Input validation and sanitization verified

### Security Requirements

- No hardcoded credentials
- Proper input validation
- Secure random number generation
- Comprehensive logging
- Rate limiting enabled by default

## 🚀 Release Process

### Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

- [ ] All tests pass
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version numbers updated
- [ ] Security review completed
- [ ] Performance testing completed

## 🤝 Community Guidelines

### Communication

- Be respectful and inclusive
- Provide constructive feedback
- Help other contributors
- Follow the project's code of conduct

### Issue Reporting

When reporting issues:

1. **Use the issue template**
2. **Provide detailed information**
3. **Include reproduction steps**
4. **Attach relevant logs**
5. **Test with latest version**

### Feature Requests

When requesting features:

1. **Describe the use case**
2. **Explain the benefits**
3. **Consider security implications**
4. **Suggest implementation approach**
5. **Be patient with responses**

## 📞 Getting Help

- **Issues**: [GitHub Issues](https://github.com/ElCruncharino/lua-resty-digest-auth/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ElCruncharino/lua-resty-digest-auth/discussions)
- **Documentation**: [README.md](README.md) and [PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)

## 🙏 Acknowledgments

Thank you for contributing to lua-resty-digest-auth! Your contributions help make this module better for everyone in the OpenResty community. 