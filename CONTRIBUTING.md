# Contributing

Pull requests are welcome. If you're planning a major change, please open an issue first to discuss it.

## Development Setup

```bash
git clone https://github.com/ElCruncharino/lua-resty-digest-auth.git
cd lua-resty-digest-auth
cd test
docker-compose up --build
```

## Testing

Please include tests for any new features or bug fixes.

```bash
cd test
docker-compose up --build
docker exec lua-resty-digest-auth-test /usr/local/bin/basic_auth_test
```

## Code Style

- Use 2-space indentation
- Follow existing Lua conventions
- Add comments for complex logic
- Validate all user inputs

## Security

If you discover a security vulnerability, please open an issue or contact me directly rather than creating a public pull request.
