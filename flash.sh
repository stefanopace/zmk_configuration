#!/usr/bin/env bash

set -euo pipefail

# Script di build+flash per ZMK usando Docker.
# Obiettivo: funzionare “out of the box” anche su un PC nuovo:
# - clona `zmk` in ~/zmk se manca
# - crea/avvia un container Docker chiamato `west` con l’immagine ZMK dev
# - inizializza `west` la prima volta (west init/update)
# - builda e copia lo UF2 quando la nice!nano monta NICENANO

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ZMK_CONFIG_DIR="$SCRIPT_DIR"
ZMK_DIR="${ZMK_DIR:-"$HOME/zmk"}"
CONTAINER_NAME="${ZMK_CONTAINER_NAME:-west}"
ZMK_IMAGE="${ZMK_IMAGE:-zmkfirmware/zmk-dev-arm:4.1-branch}"

BOARD="${BOARD:-nice_nano}"
SHIELD="${SHIELD:-contra_rgb}"

if ! command -v docker >/dev/null 2>&1; then
  echo "Errore: Docker non è installato o non è nel PATH." >&2
  exit 1
fi

if [[ ! -d "$ZMK_DIR/.git" ]]; then
  echo "Clono ZMK in \"$ZMK_DIR\"..."
  git clone https://github.com/zmkfirmware/zmk.git "$ZMK_DIR"
fi

if ! docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Creo il container Docker \"$CONTAINER_NAME\"..."
  docker run -d --name "$CONTAINER_NAME" --privileged \
    -v "$ZMK_DIR:/workspaces/zmk" \
    -v "$ZMK_CONFIG_DIR:/workspaces/zmk-config" \
    -w /workspaces/zmk \
    "$ZMK_IMAGE" \
    sleep infinity >/dev/null
else
  if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]]; then
    echo "Avvio il container Docker \"$CONTAINER_NAME\"..."
    docker start "$CONTAINER_NAME" >/dev/null
  fi
fi

echo "Inizializzo/aggiorno il workspace Zephyr (solo la prima volta può durare)..."
docker exec -it "$CONTAINER_NAME" bash -lc '
  set -euo pipefail
  cd /workspaces/zmk
  if [[ ! -d .west ]]; then
    west init -l app/
  fi
  west update
'

echo "Build ZMK (board=$BOARD shield=$SHIELD)..."
docker exec -it --workdir /workspaces/zmk/app "$CONTAINER_NAME" \
  west build --pristine -b "$BOARD" -- \
    "-DSHIELD=$SHIELD" \
    "-DZMK_CONFIG=/workspaces/zmk-config/config"

UF2_PATH="$ZMK_DIR/app/build/zephyr/zmk.uf2"
if [[ ! -f "$UF2_PATH" ]]; then
  echo "Errore: UF2 non trovato in \"$UF2_PATH\" (build fallita o path diverso)." >&2
  exit 1
fi

MOUNT1="/media/$USER/NICENANO"
MOUNT2="/run/media/$USER/NICENANO"

echo "In attesa del bootloader (cartella NICENANO)..."
while [[ ! -d "$MOUNT1" && ! -d "$MOUNT2" ]]; do
  printf "."
  sleep 1
done
echo ""

DEST="$MOUNT1"
if [[ -d "$MOUNT2" ]]; then
  DEST="$MOUNT2"
fi

echo "Copio UF2 su \"$DEST\"..."
cp "$UF2_PATH" "$DEST/"
echo "Fatto."

