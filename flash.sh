#!/usr/bin/env bash

# seguire le istruzioni per docker (https://zmk.dev/docs/development/setup)
# docker volume create --driver local -o o=bind -o type=none -o device="/home/stefano/fun/keyboards/zmk_configuration/" zmk-config

container_name=$(docker ps | grep -o "^[a-z0-9]*")
echo $container_name

docker exec -it --workdir /workspaces/zmk/app $container_name west build --pristine -b nice_nano_v2 -- -DSHIELD=contra_rgb -DZMK_CONFIG="/workspaces/zmk-config/config"

if [[ $? -ne 0 ]]; then echo "fail"; exit 1 ;fi

echo "waiting for bootloader"
while [[ ! -d "/media/stefano/NICENANO" ]]
do
  printf "."
  sleep 1
done

echo ""

cp "/home/stefano/fun/keyboards/zmk_firmware/zmk/app/build/zephyr/zmk.uf2" "/media/stefano/NICENANO"

