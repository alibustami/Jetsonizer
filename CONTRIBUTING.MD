# Contributing to Jetsonizer

Thank you for your interest in contributing to Jetsonizer!

We welcome contributions from the community to help make Jetsonizer better for everyone working with NVIDIA Jetson devices.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [Adding New Tools](#adding-new-tools)

## 📜 Code of Conduct

This project and everyone participating in it is governed by our Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and considerate in your interactions with other contributors.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (commands, error messages, screenshots)
- **Describe the behavior you observed and what you expected**
- **Include your Jetson device model and JetPack version**

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most Jetsonizer users
- **List any alternative solutions** you've considered

### Pull Requests

1. Fork the repository and create your branch from `master`
2. Make your changes following our [style guidelines](#style-guidelines)
3. Test your changes thoroughly on a Jetson device
4. Update documentation if needed
5. Write a clear commit message describing your changes

## 🛠️ Development Setup

### Prerequisites

- NVIDIA Jetson device (Nano, Xavier, Orin, Thor, etc.)
- JetPack SDK installed
- `git` and `bash` installed
- `gum` for the TUI (will be installed automatically)

### Setting Up Your Dev Environment

1. **Clone the repository:**
   ```bash
   git clone https://github.com/alibustami/Jetsonizer.git
   cd Jetsonizer
   ```

2. **Make scripts executable:**
   ```bash
   chmod +x src/main.sh
   chmod +x src/modules/*.sh
   chmod +x src/utils/*.sh
   ```

3. **Test your changes:**
   ```bash
   ./src/main.sh
   ```

## 📝 Submitting Changes

1. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: Add feature description"
   ```

2. **Push to your fork:**
   ```bash
   git push origin feature/your-feature-name
   ```

3. **Open a Pull Request:**
   - Provide a clear description of what your PR does
   - Reference any related issues
   - Include screenshots/recordings if applicable

### Commit Message Format

We follow conventional commits format:

- `feat:` - A new feature
- `fix:` - A bug fix
- `docs:` - Documentation only changes
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

Example: `feat: Add support for PyTorch 2.0 installation`

## 🎨 Style Guidelines

### Bash Scripts

- Use `#!/bin/bash` shebang
- Enable strict mode: `set -euo pipefail`
- Use meaningful variable names in `UPPER_CASE`
- Add comments for complex logic
- Use `gum` for user-facing messages and prompts
- Log success with green (`--foreground 82`)
- Log warnings with orange (`--foreground 214`)
- Log errors with red (`--foreground 196`)

### Code Structure

```bash
#!/bin/bash

set -euo pipefail

# Brief description of what this script does

gum style --foreground 82 --bold "Starting installation..."

# Your code here

gum style --foreground 82 --bold "✅ Installation completed successfully."
```

### Error Handling

Always include proper error handling:

```bash
if ! command; then
    gum style --foreground 196 --bold "❌ Command failed."
    exit 1
fi
```

## 🔧 Adding New Tools

To add support for a new tool/package:

1. **Create a new module script** in `src/modules/`:
   ```bash
   touch src/modules/install_your_tool.sh
   chmod +x src/modules/install_your_tool.sh
   ```

2. **Implement the installation logic:**
   - Check if already installed
   - Ask for confirmation if needed
   - Install the tool
   - Verify installation
   - Show success/failure message

3. **Update `src/main.sh`:**
   - Add your tool to the appropriate category array
   - Follow the existing pattern for category items

4. **Test thoroughly:**
   - Test on a fresh Jetson device if possible
   - Test reinstallation scenarios
   - Test error handling

5. **Update documentation:**
   - Add your tool to `README.md`
   - Update the project website if applicable

## 🧪 Testing

Before submitting your PR, please test:

- ✅ Fresh installation works
- ✅ Reinstallation scenario works
- ✅ Error messages are clear and helpful
- ✅ No unintended side effects
- ✅ Works on different Jetson models (if possible)

## 📞 Getting Help

If you need help or have questions:

- Open a GitHub Discussion
- Check existing issues and PRs
- Reach out to the maintainers

## 🙏 Thank You!

Your contributions make Jetsonizer better for the entire NVIDIA Jetson community. We appreciate your time and effort!

---

**Happy Contributing!**
