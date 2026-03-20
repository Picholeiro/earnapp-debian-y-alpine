# EarnApp Installer — Debian & Alpine Linux

Script de instalación de [EarnApp](https://earnapp.com) compatible con **Debian** (y derivados como Ubuntu, Raspberry Pi OS) y **Alpine Linux**.

## 📁 Estructura del proyecto

```
earnapp/
├── install.sh              # Script original (solo Debian/bash)
└── revisiones/
    └── install_v2.sh       # Script compatible con Debian + Alpine
```

## 🐧 Compatibilidad

| Característica | `install.sh` (original) | `install_v2.sh` (revisión) |
|---|---|---|
| Debian / Ubuntu | ✅ | ✅ |
| Raspberry Pi OS | ✅ | ✅ |
| Alpine Linux | ❌ | ✅ |
| Shell requerido | `bash` | `sh` (POSIX) |
| Init system | systemd | systemd + OpenRC |

## 🔧 Cambios principales en la versión compatible

- **Shebang POSIX**: `#!/bin/sh` en lugar de `#!/usr/bin/env bash`
- **Sin bashisms**: Compatible con `ash` (BusyBox) de Alpine
- **Detección de distro**: Adapta comandos automáticamente según el sistema
- **Comandos BusyBox**: Fallbacks para `hostname`, `df`, `numfmt`, `ls`, `service`
- **OpenRC**: Usa `rc-service` en Alpine en lugar de `service`

## 🚀 Uso

### En Debian / Ubuntu / Raspberry Pi OS
```bash
sudo bash install.sh
# o
sudo sh revisiones/install_v2.sh
```

### En Alpine Linux
```sh
sudo sh revisiones/install_v2.sh
```

### Modo automático (sin preguntas)
```sh
sudo sh revisiones/install_v2.sh -y
```

## 📝 Licencia

ISC (como el script original de BrightData/EarnApp)
