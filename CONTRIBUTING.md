# Contributing to FunChat

Thank you for your interest in contributing to FunChat! This document provides guidelines and instructions for contributing.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Respect differing viewpoints and experiences

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/yourusername/funchat.git`
3. Create a branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test your changes
6. Commit: `git commit -m "Add your feature"`
7. Push: `git push origin feature/your-feature-name`
8. Create a Pull Request

## Development Setup

See [README.md](README.md) for setup instructions.

## Code Style

### Flutter/Dart
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use `flutter analyze` to check for issues
- Format code with `dart format .`
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### TypeScript (Backend)
- Use TypeScript strict mode
- Follow ESLint rules
- Use async/await for asynchronous operations
- Add JSDoc comments for public APIs

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing
- Test on both Android and iOS
- Test with multiple devices
- Test offline scenarios
- Test with poor network conditions

## Pull Request Guidelines

### Before Submitting
- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] No console.log or print statements (unless for debugging)
- [ ] No commented-out code
- [ ] Commit messages are clear and descriptive

### PR Description Should Include
- What changes were made
- Why the changes were made
- How to test the changes
- Screenshots (for UI changes)
- Related issue numbers

### Example PR Description
```markdown
## Description
Added support for sending image attachments in chat.

## Changes
- Added image picker integration
- Implemented image compression
- Added thumbnail generation
- Updated UI to show image previews

## Testing
1. Open a chat
2. Tap attachment button
3. Select an image
4. Verify image is compressed and sent
5. Verify thumbnail appears in chat

## Screenshots
[Add screenshots here]

Fixes #123
```

## Feature Requests

To request a feature:
1. Check if it already exists in Issues
2. Create a new issue with "Feature Request" label
3. Describe the feature and use case
4. Explain why it would be valuable

## Bug Reports

To report a bug:
1. Check if it's already reported
2. Create a new issue with "Bug" label
3. Include:
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Screenshots/logs
   - Device/OS information
   - App version

### Bug Report Template
```markdown
## Description
Brief description of the bug

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Environment
- Device: [e.g., Pixel 6]
- OS: [e.g., Android 13]
- App Version: [e.g., 1.0.0]

## Logs
```
[Paste relevant logs here]
```

## Screenshots
[Add screenshots here]
```

## Areas for Contribution

### High Priority
- [ ] Group chat support
- [ ] Voice/video calls
- [ ] File attachment support
- [ ] Message search
- [ ] Push notifications

### Medium Priority
- [ ] Message reactions
- [ ] Chat backup/restore
- [ ] Desktop apps
- [ ] Stickers/GIFs
- [ ] Voice messages

### Low Priority
- [ ] Custom themes
- [ ] Chat wallpapers
- [ ] Message scheduling
- [ ] Chat bots
- [ ] Integrations

## Architecture Guidelines

### Adding New Features

1. **Database Changes**
   - Update `lib/data/database/database.dart`
   - Run code generation
   - Add migration if needed

2. **Business Logic**
   - Add to appropriate repository in `lib/data/repositories/`
   - Keep logic separate from UI

3. **State Management**
   - Add Riverpod providers in `lib/providers/`
   - Use StreamProvider for reactive data
   - Use StateProvider for simple state

4. **UI**
   - Add screens to `lib/presentation/screens/`
   - Add reusable widgets to `lib/presentation/widgets/`
   - Follow Material Design guidelines
   - Ensure responsive design

5. **Testing**
   - Add unit tests for business logic
   - Add widget tests for UI components
   - Add integration tests for user flows

## Security Considerations

When contributing, keep security in mind:
- Never log sensitive data (keys, messages)
- Validate all user input
- Use secure storage for sensitive data
- Follow cryptographic best practices
- Don't introduce dependencies with known vulnerabilities

## Documentation

- Update README.md for user-facing changes
- Update DEPLOYMENT.md for deployment changes
- Add inline comments for complex code
- Update API documentation
- Add examples for new features

## Questions?

- Open a Discussion on GitHub
- Join our Discord server
- Email: dev@funchat.local

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing to FunChat! 🎉
