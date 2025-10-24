#!/usr/bin/env bash
# Module: install
# Description: Instalador de ShFlow en modo local o global
# License: GPLv3
# Author: Luis GuLo
# Version: 1.3.0

set -e

# 🌐 Detectar idioma del sistema
LANGUAGE="es"
[[ "${LANG,,}" != *es* ]] && LANGUAGE="en"

# 🗣️ Mensajes traducidos
declare -A tr

if [[ "$LANGUAGE" == "es" ]]; then
  tr[logo]="🐙 SHFLOW"
  tr[mode]="🔧 Instalando ShFlow en modo: %s"
  tr[folder]="📁 Carpeta de instalación: %s"
  tr[prev_detected]="⚠️ Instalación previa detectada en %s"
  tr[preserve_vault]="📦 Preservando vault existente..."
  tr[preserve_inventory]="📦 Preservando inventory existente..."
  tr[preserve_modules]="📦 Preservando user_modules existente..."
  tr[removing_old]="🧹 Eliminando instalación previa..."
  tr[copying]="📦 Copiando archivos..."
  tr[restore_vault]="🔁 Restaurando vault..."
  tr[restore_inventory]="🔁 Restaurando inventory..."
  tr[restore_modules]="🔁 Restaurando user_modules..."
  tr[env_added]="✅ Variables añadidas a %s"
  tr[env_exists]="ℹ️ SHFLOW_HOME ya está definido en %s"
  tr[done]="🎉 Instalación completada correctamente."
  tr[installed]="📦 Proyecto instalado en: %s"
  tr[symlinks]="🔗 Symlinks creados en: %s"
  tr[restart]="🧠 Recuerda reiniciar tu terminal o ejecutar: source %s"
  tr[run]="👉 Puedes ejecutar 'shflow' desde cualquier ruta del terminal."
else
  tr[logo]="🐙 SHFLOW"
  tr[mode]="🔧 Installing ShFlow in mode: %s"
  tr[folder]="📁 Installation folder: %s"
  tr[prev_detected]="⚠️ Previous installation detected at %s"
  tr[preserve_vault]="📦 Preserving existing vault..."
  tr[preserve_inventory]="📦 Preserving existing inventory..."
  tr[preserve_modules]="📦 Preserving existing user_modules..."
  tr[removing_old]="🧹 Removing previous installation..."
  tr[copying]="📦 Copying files..."
  tr[restore_vault]="🔁 Restoring vault..."
  tr[restore_inventory]="🔁 Restoring inventory..."
  tr[restore_modules]="🔁 Restoring user_modules..."
  tr[env_added]="✅ Variables added to %s"
  tr[env_exists]="ℹ️ SHFLOW_HOME already defined in %s"
  tr[done]="🎉 Installation completed successfully."
  tr[installed]="📦 Project installed at: %s"
  tr[symlinks]="🔗 Symlinks created at: %s"
  tr[restart]="🧠 Remember to restart your terminal or run: source %s"
  tr[run]="👉 You can run 'shflow' from any terminal path."
fi

# 🖼️ Logo
[[ -f "shflow-logo.ascii" ]] && cat shflow-logo.ascii || echo "${tr[logo]}"

# 🧭 Detectar modo de instalación
if [[ "$EUID" -eq 0 ]]; then
  INSTALL_DIR="/opt/shflow"
  BIN_DIR="/usr/local/bin"
  MODE="global"
else
  INSTALL_DIR="$HOME/shflow"
  BIN_DIR="$HOME/.local/bin"
  MODE="local"
fi

printf "${tr[mode]}\n" "$MODE"
printf "${tr[folder]}\n" "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# 🧹 Limpiar instalación previa
if [[ -d "$INSTALL_DIR" ]]; then
  printf "${tr[prev_detected]}\n" "$INSTALL_DIR"

  [[ -d "$INSTALL_DIR/core/vault" ]] && echo "${tr[preserve_vault]}" && mv "$INSTALL_DIR/core/vault" /tmp/shflow_vault_backup
  [[ -d "$INSTALL_DIR/core/inventory" ]] && echo "${tr[preserve_inventory]}" && mv "$INSTALL_DIR/core/inventory" /tmp/shflow_inventory_backup
  [[ -d "$INSTALL_DIR/user_modules" ]] && echo "${tr[preserve_modules]}" && mv "$INSTALL_DIR/user_modules" /tmp/shflow_user_modules_backup

  echo "${tr[removing_old]}"
  rm -rf "$INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# 📥 Copiar archivos
echo "${tr[copying]}"
for file in shflow.sh shflow.tr.es shflow.tr.en vault.sh vault.tr.es vault.tr.en LICENSE README.md; do cp "$file" "$INSTALL_DIR/"; done
for dir in core community_modules user_modules examples; do cp -r "$dir" "$INSTALL_DIR/"; done

# 🔁 Restaurar backups
[[ -d "/tmp/shflow_vault_backup" ]] && echo "${tr[restore_vault]}" && rm -rf "$INSTALL_DIR/core/vault" && mv /tmp/shflow_vault_backup "$INSTALL_DIR/core/vault"
[[ -d "/tmp/shflow_inventory_backup" ]] && echo "${tr[restore_inventory]}" && rm -rf "$INSTALL_DIR/core/inventory" && mv /tmp/shflow_inventory_backup "$INSTALL_DIR/core/inventory"
[[ -d "/tmp/shflow_user_modules_backup" ]] && echo "${tr[restore_modules]}" && rm -rf "$INSTALL_DIR/user_modules" && mv /tmp/shflow_user_modules_backup "$INSTALL_DIR/user_modules"

# 🔗 Symlinks
ln -sf "$INSTALL_DIR/shflow.sh" "$BIN_DIR/shflow"
ln -sf "$INSTALL_DIR/vault.sh" "$BIN_DIR/shflow-vault"
ln -sf "$INSTALL_DIR/core/utils/shflow-doc.sh" "$BIN_DIR/shflow-doc"
ln -sf "$INSTALL_DIR/core/utils/module-docgen.sh" "$BIN_DIR/module-docgen"
ln -sf "$INSTALL_DIR/core/utils/shflow-check.sh" "$BIN_DIR/shflow-check"
ln -sf "$INSTALL_DIR/core/utils/shflow-trust.sh" "$BIN_DIR/shflow-trust"
ln -sf "$INSTALL_DIR/core/utils/shflow-ssh-init.sh" "$BIN_DIR/shflow-ssh-init"
ln -sf "$INSTALL_DIR/core/utils/vault-init.sh" "$BIN_DIR/vault-init"

# 🧠 Variables de entorno
PROFILE_FILE="$HOME/.bashrc"
[[ "$SHELL" == *zsh ]] && PROFILE_FILE="$HOME/.zshrc"

if ! grep -q "SHFLOW_HOME" "$PROFILE_FILE"; then
  echo "export SHFLOW_HOME=\"$INSTALL_DIR\"" >> "$PROFILE_FILE"
  echo "export PATH=\"\$PATH:$BIN_DIR\"" >> "$PROFILE_FILE"
  printf "${tr[env_added]}\n" "$PROFILE_FILE"
else
  printf "${tr[env_exists]}\n" "$PROFILE_FILE"
fi

# ✅ Finalización
echo ""
echo "${tr[done]}"
printf "${tr[installed]}\n" "$INSTALL_DIR"
printf "${tr[symlinks]}\n" "$BIN_DIR"
printf "${tr[restart]}\n" "$PROFILE_FILE"
echo "${tr[run]}"
