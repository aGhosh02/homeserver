# Contributing Guidelines

Thank you for your interest in contributing to the Proxmox Homeserver Automation project! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues
- **Bug Reports**: Use the GitHub issue template for bugs
- **Feature Requests**: Clearly describe the desired functionality
- **Security Issues**: Report privately via email first

### Pull Requests
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

## 📋 Development Setup

### Prerequisites
- **Git** for version control
- **Ansible** 2.12+ for automation
- **Python** 3.8+ for development tools
- **Make** for task automation

### Local Development
```bash
# Clone your fork
git clone https://github.com/your-username/homeserver.git
cd homeserver

# Setup development environment
make dev-setup

# Install dependencies
make setup

# Validate configuration
make config-validate
```

## 🔧 Code Standards

### Ansible Best Practices
- **Idempotency**: Tasks should be idempotent
- **Variables**: Use descriptive variable names
- **Tags**: Apply appropriate tags to tasks
- **Documentation**: Include task descriptions
- **Error Handling**: Handle errors gracefully

### YAML Formatting
```yaml
---
# Good example
- name: Install essential packages
  package:
    name: "{{ item }}"
    state: present
  loop:
    - curl
    - wget
    - vim
  tags: ['packages', 'essential']
```

### Directory Structure
```
ansible/
├── inventories/
│   └── production/
│       ├── hosts.yml
│       └── group_vars/
├── playbooks/
│   ├── site.yml
│   └── *.yml
├── roles/
│   └── rolename/
│       ├── tasks/main.yml
│       ├── defaults/main.yml
│       ├── handlers/main.yml
│       ├── templates/
│       └── files/
└── requirements.yml
```

### Role Development
- **Structure**: Follow Ansible Galaxy role structure
- **Defaults**: Provide sensible defaults
- **Documentation**: Document role variables
- **Testing**: Include role-specific tests

## 🧪 Testing

### Before Submitting
```bash
# Run all tests
make full-test

# Validate configuration
make config-validate

# Check syntax
make syntax-check

# Run linting
make lint

# Security check
make security-check
```

### Test Categories
- **Syntax Tests**: YAML and Ansible syntax validation
- **Lint Tests**: Code quality and best practices
- **Security Tests**: Security configuration validation
- **Integration Tests**: End-to-end deployment testing

## 📝 Documentation

### Requirements
- **README Updates**: Update README.md for new features
- **Inline Comments**: Add comments for complex logic
- **Role Documentation**: Document role variables and usage
- **Changelog**: Update CHANGELOG.md

### Documentation Standards
- **Clear Language**: Use clear, concise language
- **Examples**: Provide practical examples
- **Screenshots**: Include screenshots where helpful
- **Links**: Keep links up to date

## 🔄 Git Workflow

### Branch Naming
- **Feature**: `feature/description`
- **Bugfix**: `bugfix/description`
- **Hotfix**: `hotfix/description`
- **Documentation**: `docs/description`

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add GPU passthrough automation
fix: resolve network bridge configuration issue
docs: update installation guide
test: add role validation tests
```

### Commit Guidelines
- **Small Commits**: Make small, focused commits
- **Clear Messages**: Write clear commit messages
- **Sign Commits**: Sign commits if possible
- **Squash**: Squash related commits before merging

## 🚀 Release Process

### Versioning
We use [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

### Release Checklist
- [ ] Update version numbers
- [ ] Update CHANGELOG.md
- [ ] Test all functionality
- [ ] Update documentation
- [ ] Create release notes

## 🏷️ Issue Labels

### Type Labels
- `bug`: Something isn't working
- `enhancement`: New feature or request
- `documentation`: Improvements to documentation
- `question`: Further information is requested

### Priority Labels
- `critical`: Critical issues requiring immediate attention
- `high`: High priority issues
- `medium`: Medium priority issues
- `low`: Low priority issues

### Status Labels
- `needs-triage`: Needs initial review
- `in-progress`: Currently being worked on
- `blocked`: Blocked by external dependencies
- `ready-for-review`: Ready for code review

## 🤔 Getting Help

### Communication Channels
- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Email**: For private security issues

### Resources
- **Ansible Documentation**: https://docs.ansible.com/
- **Proxmox Documentation**: https://pve.proxmox.com/wiki/
- **Project Documentation**: See `docs/` directory

## 📜 Code of Conduct

### Our Pledge
We pledge to make participation in our project a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards
Examples of behavior that contributes to creating a positive environment include:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

### Enforcement
Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances.

## 🎯 Contribution Areas

### High Priority
- **Security Improvements**: Enhance security configurations
- **Performance Optimization**: Improve deployment performance
- **Error Handling**: Better error handling and recovery
- **Documentation**: Improve and expand documentation

### Medium Priority
- **New Features**: Add new automation capabilities
- **Testing**: Expand test coverage
- **Monitoring**: Add monitoring and alerting
- **Backup Solutions**: Implement backup automation

### Low Priority
- **UI Improvements**: Enhance user interface elements
- **Code Cleanup**: Refactor and clean up code
- **Examples**: Add more usage examples
- **Integration**: Integrate with other tools

## 🏆 Recognition

### Contributors
We recognize and appreciate all contributors:
- **Code Contributors**: Those who contribute code
- **Documentation Contributors**: Those who improve documentation
- **Bug Reporters**: Those who report issues
- **Feature Requesters**: Those who suggest improvements

### Hall of Fame
Outstanding contributors may be featured in our README and release notes.

## 📧 Contact

For questions about contributing, please:
1. Check existing issues and documentation
2. Open a GitHub issue for bugs or features
3. Start a GitHub discussion for questions
4. Email maintainers for security issues

Thank you for contributing to the Proxmox Homeserver Automation project! 🚀
