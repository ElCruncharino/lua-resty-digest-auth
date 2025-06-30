---
name: Bug report
about: Create a report to help us improve
title: '[BUG] '
labels: ['bug']
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Configure nginx with '...'
2. Set up credentials file with '....'
3. Make request to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Actual behavior**
A clear and concise description of what actually happened.

**Environment (please complete the following information):**
 - OS: [e.g. Ubuntu 20.04, CentOS 8]
 - OpenResty version: [e.g. 1.21.4.1]
 - Module version: [e.g. 1.0.0]
 - Installation method: [e.g. OPM, manual, Docker]

**Configuration**
Please share your nginx configuration (with sensitive information redacted):

```nginx
# Your nginx configuration here
```

**Credentials file format** (with sensitive information redacted):
```
# Format: username:realm:HA1_hash
```

**Logs**
Please share relevant logs (with sensitive information redacted):

```bash
# Error logs
tail -n 50 /var/log/nginx/error.log

# Access logs
tail -n 20 /var/log/nginx/access.log
```

**Additional context**
Add any other context about the problem here.

**Testing**
- [ ] I have tested with the latest version
- [ ] I have checked the documentation
- [ ] I have searched existing issues
- [ ] I can reproduce this issue consistently 