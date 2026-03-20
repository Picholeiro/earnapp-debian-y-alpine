# EarnApp Installer — Debian & Alpine Linux

Script de instalación de [EarnApp](https://earnapp.com) compatible con **Debian** (y derivados como Ubuntu, Raspberry Pi OS) y **Alpine Linux**.

## 📥 Descarga

### Desde GitHub Releases (recomendado)

[![Release v1.0.0](https://img.shields.io/github/v/release/Picholeiro/earnapp-debian-y-alpine)](https://github.com/Picholeiro/earnapp-debian-y-alpine/releases/latest)

```bash
wget https://github.com/Picholeiro/earnapp-debian-y-alpine/releases/download/v1.0.0/install_v2.sh
chmod +x install_v2.sh
sudo sh install_v2.sh -y
```

### Desde el repositorio

**Clonar el repositorio completo:**
```bash
git clone https://github.com/Picholeiro/earnapp-debian-y-alpine.git
cd earnapp-debian-y-alpine
```

**Descargar solo el script compatible (Debian + Alpine):**
```bash
wget https://raw.githubusercontent.com/Picholeiro/earnapp-debian-y-alpine/master/revisiones/install_v2.sh
chmod +x install_v2.sh
```

**O con curl:**
```bash
curl -O https://raw.githubusercontent.com/Picholeiro/earnapp-debian-y-alpine/master/revisiones/install_v2.sh
chmod +x install_v2.sh
```

**Descargar el script original (solo Debian):**
```bash
wget https://raw.githubusercontent.com/Picholeiro/earnapp-debian-y-alpine/master/install.sh
chmod +x install.sh
```

## 📁 Estructura del proyecto

```
earnapp/
├── install.sh              # Script original (solo Debian/bash)
├── README.md               # Esta documentación
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

### Arquitecturas soportadas

| Arquitectura | Nombre del binario |
|---|---|
| `x86_64` / `amd64` | `earnapp-x64` |
| `aarch64` / `arm64` | `earnapp-aarch64` |
| `armv7l` / `armv6l` | `earnapp-arm7l` |

## 🚀 Uso

### Sintaxis

```
sudo sh install_v2.sh [OPCIONES] [PRODUCTO]
```

### Parámetros

| Parámetro | Posición | Descripción | Valores | Por defecto |
|---|---|---|---|---|
| `-y` | `$1` | Modo automático (acepta términos sin preguntar) | `-y` o nada | Interactivo |
| `PRODUCTO` | `$2` | Producto a instalar | `earnapp` o `piggybox` | `earnapp` |

### Variable de entorno

| Variable | Descripción | Por defecto |
|---|---|---|
| `BASE_URL` | URL base para descargar el binario | `https://cdn-earnapp.b-cdn.net/static` |

### Ejemplos

**Instalación interactiva estándar (Debian o Alpine):**
```sh
sudo sh install_v2.sh
```

**Instalación automática sin preguntas:**
```sh
sudo sh install_v2.sh -y
```

**Instalar producto PiggyBox:**
```sh
sudo sh install_v2.sh -y piggybox
```

**Usar un servidor CDN alternativo:**
```sh
sudo BASE_URL="https://mi-servidor.com/archivos" sh install_v2.sh -y
```

**En Debian también se puede usar el script original con bash:**
```bash
sudo bash install.sh
```

## 🔧 Cambios principales en la versión compatible

- **Shebang POSIX**: `#!/bin/sh` en lugar de `#!/usr/bin/env bash`
- **Sin bashisms**: Compatible con `ash` (BusyBox) de Alpine
- **Detección de distro**: Adapta comandos automáticamente según el sistema
- **Comandos BusyBox**: Fallbacks para `hostname`, `df`, `numfmt`, `ls`, `service`
- **OpenRC**: Usa `rc-service` en Alpine en lugar de `service`

## ⚙️ Requisitos previos

- Ejecutar como **root** (`sudo`)
- **200 MB** de espacio libre en disco
- `wget` instalado (para descargar el binario)
- `curl` o `wget` (para reportar telemetría)
- Conexión a Internet

## 📝 Licencia

ISC (como el script original de BrightData/EarnApp)
