

<div align="center">

# Jetsonizer

**Configuración más fluida y rápida para NVIDIA Jetson**

<!-- [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) -->
[![Platform](https://img.shields.io/badge/platform-NVIDIA%20Jetson-76B900.svg)](https://developer.nvidia.com/embedded-computing)
[![Shell](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![GitHub Stars](https://img.shields.io/github/stars/alibustami/Jetsonizer?style=social)](https://github.com/alibustami/Jetsonizer)

---

**Jetsonizer** es una herramienta de línea de comandos (CLI) diseñada para simplificar y automatizar el proceso de configuración de dispositivos NVIDIA Jetson. Configurar un entorno Jetson desde cero puede ser tedioso y propenso a errores. Jetsonizer simplifica este proceso gestionando la creación de usuarios y la instalación de paquetes esenciales en un único flujo de trabajo interactivo.

[Instalación](#-installation) •
[Características](#-features) •
[Herramientas Compatibles](#️-currently-supported-tools) •
[Modelos Jetson Compatibles](#supported-jetson-models) •
[Uso](#usage) •
[Contribuir](#-contributing)
[Citación](#-cite-us) •

</div>

---

## ✨ Características

- **Configuración Interactiva** - TUI impulsada por [gum](https://github.com/charmbracelet/gum)
- **Stack de IA y Visión** - OpenCV con soporte CUDA, PyTorch, TensorRT
- **Entornos de Python** - Soporte para MiniConda y uv
- **Herramientas de Desarrollo** - VS Code, herramientas de monitoreo, navegadores
- **Cero Configuración** - Valores predeterminados inteligentes con opciones de personalización

## 📦 Instalación

Agrega el repositorio de Jetsonizer e instálalo mediante `apt`:

```bash
echo "deb [trusted=yes] https://alibustami.github.io/Jetsonizer/ debian/" | sudo tee /etc/apt/sources.list.d/jetsonizer.list
```

```bash
sudo apt update
sudo apt install jetsonizer
```

##  Uso

Simplemente ejecuta:

```bash
jetsonizer
```

Sigue las instrucciones interactivas para configurar tu dispositivo Jetson.

<div align="center">
  <img src="assets/install.gif" alt="Jetsonizer Demo" width="800">
  <p><em>Jetsonizer en acción: Automatizando la configuración de tu Jetson</em></p>
</div>

## 🛠️ Herramientas Actualmente Soportadas

Jetsonizer puede instalar y configurar las siguientes herramientas:

### Stack de IA y Visión
- **OpenCV (CUDA)**
- **PyTorch (CUDA)**
- **TensorRT** - Inferencia de aprendizaje profundo de alto rendimiento

### Entornos y Herramientas de Python
- **MiniConda**
- **uv** 

### IDEs
- **VS Code**

### Monitoreo
- **jtop** - Herramienta de monitoreo del sistema para dispositivos Jetson

### Navegadores
- **Brave Browser**

## Modelos Jetson Compatibles

Todas las características de Jetsonizer listadas arriba funcionan y han sido probadas en cada modelo.

| Característica | Thor (JP 7.0) | AGX Orin (JP 6.2) | Orin Nano (JP 6.2) |
| --- | --- | --- | --- |
| OpenCV (CUDA) | ✅ | ✅ | ✅ |
| PyTorch (CUDA) | ✅ | ✅ | ✅ |
| TensorRT | ✅ | ✅ | ✅ |
| MiniConda | ✅ | ✅ | ✅ |
| uv | ✅ | ✅ | ✅ |
| VS Code | ✅ | ✅ | ✅ |
| jtop | ✅ | ✅ | ✅ |
| Brave Browser | ✅ | ✅ | ✅ |


## 📖 Documentación

Para más detalles, visita el [sitio web del proyecto](https://alibustami.github.io/Jetsonizer/).

## 📚 Cítanos

Si utilizas Jetsonizer en tu investigación, por favor cítalo (DOI: `10.5281/zenodo.18181257`).

```bibtex
@software{jetsonizer,
  author       = {Ali Al-Bustami and
                  Zaid Ghazal and
                  Humberto Ruiz-Ochoa},
  title        = {alibustami/Jetsonizer: Jetsonizer v1.0.0},
  month        = jan,
  year         = 2026,
  publisher    = {Zenodo},
  version      = {v1.0.0},
  doi          = {10.5281/zenodo.18181257},
  url          = {https://doi.org/10.5281/zenodo.18181257},
}
```

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Por favor, lee nuestras [Guías de Contribución](CONTRIBUTING.MD) antes de enviar un PR.

## 👥 Autores

- **[Ali Al-Bustami](https://alibustami.github.io/)**
- **[Humberto Ruiz-Ochoa](https://www.linkedin.com/in/humberto-ruiz-ochoa/)**
- **[Zaid Ghazal](https://zaidghazal.github.io/)**

## 📄 Licencia

Este proyecto está licenciado bajo la Licencia MIT - consulta el archivo [LICENSE](LICENSE) para más detalles.

## ⭐ Muestra tu Apoyo

Si encuentras útil Jetsonizer, por favor considera darle una estrella en [GitHub](https://github.com/alibustami/Jetsonizer)!

---

<div align="center">

**Hecho para la Comunidad NVIDIA Jetson**

</div>
