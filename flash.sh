#!/usr/bin/env bash

container_name=$(docker ps | grep -o "^[a-z0-9]*")
echo $container_name

docker exec -it --workdir /workspaces/zmk/app $container_name west build -b nice_nano -- -DSHIELD=contra -DZMK_CONFIG="/workspaces/zmk-config/config"

echo "waiting for bootloader"
while [[ ! -d "/media/stefano/NICENANO" ]]
do
  printf "."
  sleep 1
done

echo ""

cp "/home/stefano/work-in-progress/zmk/app/build/zephyr/zmk.uf2" "/media/stefano/NICENANO"