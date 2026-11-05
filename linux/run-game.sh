#!/usr/bin/env bash
# Camada de compatibilidade: roda o build Windows do Rockman X Survivors sob Proton.
# Tudo (prefixo, logs, saves) fica dentro desta pasta do projeto.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="$ROOT/game"
COMPAT="$ROOT/linux/prefix"
EXE="$GAME_DIR/RockmanXSurvivors.exe"

# unzip não preserva o bit de execução; sem isto o Proton recusa o launch.
[ -f "$EXE" ] && chmod +x "$GAME_DIR"/*.exe 2>/dev/null || true

# Proton mais recente instalado pelo Steam (aceita PROTON_OVERRIDE para escolher outro).
# Ordena pelo número do nome: "Proton 10.0" > "Proton 9.0 (Beta)" > "Proton 7.0".
# Entradas sem número (Experimental, Hotfix) ficam como último recurso.
if [ -n "${PROTON_OVERRIDE:-}" ]; then
  PROTON_DIR="$PROTON_OVERRIDE"
else
  STEAM_COMMON="$HOME/.local/share/Steam/steamapps/common"
  PROTON_DIR="$(find "$STEAM_COMMON" -maxdepth 1 -type d -name 'Proton [0-9]*' 2>/dev/null \
    | awk -F'Proton ' '{print $2, $0}' | sort -V | tail -1 | cut -d' ' -f2-)"
  [ -n "$PROTON_DIR" ] || PROTON_DIR="$(find "$STEAM_COMMON" -maxdepth 1 -type d -name 'Proton*' 2>/dev/null | sort | tail -1)"
fi
[ -n "$PROTON_DIR" ] && [ -x "$PROTON_DIR/proton" ] || { echo "Proton não encontrado em $HOME/.local/share/Steam/steamapps/common"; exit 1; }
[ -f "$EXE" ] || { echo "Build não encontrado: $EXE (extraia a release em game/)"; exit 1; }
# O filelock do Proton abre pfx.lock sem criar o diretório-pai.
mkdir -p "$COMPAT/logs"

export STEAM_COMPAT_DATA_PATH="$COMPAT"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="$HOME/.local/share/Steam"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEESYNC=1
export WINEFSYNC=1
export PROTON_ENABLE_WAYLAND="${PROTON_ENABLE_WAYLAND:-1}"
export PROTON_DISABLE_HANDSHAKE="${PROTON_DISABLE_HANDSHAKE:-}"
export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
export MESA_GL_VERSION_OVERRIDE="${MESA_GL_VERSION_OVERRIDE:-}"

# gamemode + mangohud são opcionais: entram só se existirem.
PREFIX_CMD=()
command -v gamemoderun >/dev/null && PREFIX_CMD+=(gamemoderun)
if [ "${MANGOHUD:-0}" = "1" ] && command -v mangohud >/dev/null; then
  PREFIX_CMD+=(mangohud)
  export MANGOHUD_CONFIG="position=top-left,font_size=18"
fi

echo "Proton: $PROTON_DIR"
echo "Prefixo: $COMPAT"
echo "Jogo: $EXE"

cd "$GAME_DIR"
exec "${PREFIX_CMD[@]}" "$PROTON_DIR/proton" waitforexitandrun "$EXE" "$@"
