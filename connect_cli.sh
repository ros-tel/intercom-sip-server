#!/bin/bash

source .env

docker compose exec -it sip-server /usr/local/freeswitch/bin/fs_cli -rRS --password ${SOCKET_PASSWORD}
