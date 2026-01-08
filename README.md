<div align="center">

# Jetsonizer

**Smoother and Faster NVIDIA Jetson Setup**

<!-- [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) -->
[![Platform](https://img.shields.io/badge/platform-NVIDIA%20Jetson-76B900.svg)](https://developer.nvidia.com/embedded-computing)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub Stars](https://img.shields.io/github/stars/alibustami/Jetsonizer?style=social)](https://github.com/alibustami/Jetsonizer)

---

**Jetsonizer** is a CLI tool designed to streamline and automate the setup process for NVIDIA Jetson devices. Setting up a fresh Jetson environment can be tedious and prone to errors. Jetsonizer simplifies this by handling user creation and essential package installations in a single, interactive workflow.

[Installation](#-installation) •
[Features](#-features) •
[Supported Tools](#️-currently-supported-tools) •
[Supported Jetson Models](#supported-jetson-models) •
[Usage](#usage) •
[Contributing](#-contributing)

</div>

---

## ✨ Features

- **Interactive Setup** - TUI powered by [gum](https://github.com/charmbracelet/gum)
- **ML & Vision Stack** - CUDA-enabled OpenCV, PyTorch, TensorRT
- **Python Environments** - MiniConda, uv support
- **Development Tools** - VS Code, monitoring tools, browsers
- **Zero-Config** - Smart defaults with customization options

## 📦 Installation

Add the Jetsonizer repository and install via `apt`:

```bash
echo "deb [trusted=yes] https://alibustami.github.io/Jetsonizer/ debian/" | sudo tee /etc/apt/sources.list.d/jetsonizer.list
```

```bash
sudo apt update
sudo apt install jetsonizer
```

##  Usage

Simply run:

```bash
jetsonizer
```

Follow the interactive prompts to configure your Jetson device.

<div align="center">
  <img src="assets/install.gif" alt="Jetsonizer Demo" width="800">
  <p><em>Jetsonizer in action: Automating your Jetson setup</em></p>
</div>

## 🛠️ Currently Supported Tools

Jetsonizer can install and configure the following tools:

### ML & Vision Stack
- **OpenCV (CUDA)**
- **PyTorch (CUDA)**
- **TensorRT** - High-performance deep learning inference

### Python Env & Tooling
- **MiniConda**
- **uv** 

### IDEs
- **VS Code**

### Monitoring
- **jtop** - System monitoring tool for Jetson devices

### Browsers
- **Brave Browser**

## Supported Jetson Models

All Jetsonizer features listed above are working and tested on each model.

| Feature | Thor | AGX Orin | Orin Nano |
| --- | --- | --- | --- |
| OpenCV (CUDA) | ✅ | ✅ | ✅ |
| PyTorch (CUDA) | ✅ | ✅ | ✅ |
| TensorRT | ✅ | ✅ | ✅ |
| MiniConda | ✅ | ✅ | ✅ |
| uv | ✅ | ✅ | ✅ |
| VS Code | ✅ | ✅ | ✅ |
| jtop | ✅ | ✅ | ✅ |
| Brave Browser | ✅ | ✅ | ✅ |


## 📖 Documentation

For more details, visit the [project website](https://alibustami.github.io/Jetsonizer/).

## 🤝 Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.MD) before submitting a PR.

## 👥 Authors

- **[Ali Al-Bustami](https://alibustami.github.io/)**
- **[Humberto Ruiz-Ochoa](https://www.linkedin.com/in/humberto-ruiz-ochoa/)**
- **[Zaid Ghazal](https://zaidghazal.github.io/)**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Show Your Support

If you find Jetsonizer helpful, please consider giving it a star on [GitHub](https://github.com/alibustami/Jetsonizer)!

---

<div align="center">

**Made for the NVIDIA Jetson Community**

</div>
