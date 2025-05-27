#!/bin/bash

# Функция для генерации случайного 32-значного пароля
generate_password() {
  local PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9_' < /dev/urandom | head -c 32)
  echo $PASSWORD
}

# Проверка и установка пароля для SOCKET_PASSWORD
if [ -z "$SOCKET_PASSWORD" ]; then
  SOCKET_PASSWORD=$(generate_password)
  echo "SOCKET_PASSWORD не был передан. Сгенерирован случайный пароль: $SOCKET_PASSWORD"
fi

# Проверка и установка пароля для SIP_PASSWORD
if [ -z "$SIP_PASSWORD" ]; then
  SIP_PASSWORD=$(generate_password)
  echo "SIP_PASSWORD не был передан. Сгенерирован случайный пароль: $SIP_PASSWORD"
fi

# Проверка наличия IP
if [ -z "$SIP_IP" ]; then
  echo "Error: SIP IP is not set"
  exit 1
fi

# Замена паролей и IP в конфигурационных файлах
sed -i "s/\$\$SOCKET_PASSWORD/${SOCKET_PASSWORD}/g" /usr/local/freeswitch/conf/autoload_configs/event_socket.conf.xml
sed -i "s/\$\$SIP_IP/${SIP_IP}/g" /usr/local/freeswitch/conf/vars.xml
sed -i -E "s!<X-PRE-PROCESS cmd=\"set\" data=\"default_password=[^\"]*\"/>!<X-PRE-PROCESS cmd=\"set\" data=\"default_password=${SIP_PASSWORD}\"/>!" /usr/local/freeswitch/conf/vars.xml

mv -f /usr/local/freeswitch/conf/sip_profiles/external.xml /usr/local/freeswitch/conf/sip_profiles/external.xml.noload
mv -f /usr/local/freeswitch/conf/sip_profiles/external-ipv6.xml /usr/local/freeswitch/conf/sip_profiles/external-ipv6.xml.noload

# Запуск FreeSwitch
exec /usr/local/freeswitch/bin/freeswitch
