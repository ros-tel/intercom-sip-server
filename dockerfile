# Используем базовый образ Ubuntu
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Moscow

# Устанавливаем зависимости
RUN apt-get update && apt-get install -yq \
    gnupg2 \
    wget \
    lsb-release \
    git \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    cmake \
    nasm \
    libtiff-dev \
    libssl-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libpcre3-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libldns-dev \
    libedit-dev \
    liblua5.3-dev \
    libopus-dev \
    libsndfile-dev \
    uuid-dev \
    tzdata \
    autoconf \
    automake \
    g++ \
    git \
    libjpeg-dev \
    libncurses5-dev \
    libtool \
    make \
    python \
    gnutls-bin \
    gawk \
    gnutls-dev \
    libssl-dev \
    zlib1g-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libpcre3-dev \
    libspeexdsp-dev \
    libedit-dev \
    libldns-dev \
    libopus-dev \
    libsndfile1-dev \
    libavformat-dev \
    libswscale-dev \
    libavresample-dev \
    libavutil-dev \
    libopus-dev \
    libcurl4-openssl-dev \
    libtiff5-dev \
    yasm \
    nasm \
    libvpx-dev \
    libavcodec-dev \
    libx264-dev \
    uuid-dev \
    php-dev \
    python3-dev \
    curl \
    cmake && \
    ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata

# Скачиваем и устанавливаем libks2 - зависимость FS
RUN git clone https://github.com/signalwire/libks.git /usr/local/src/libks -bv2.0.4 && \
    cd /usr/local/src/libks && \
    cmake . && \
    make && \
    make install

# Скачиваем Sofia SIP, SpanDSP (Для DTMF) и сам FreeSwitch
RUN git clone https://github.com/freeswitch/sofia-sip.git /usr/local/src/sofia -bv1.13.17

# У SpandSP нет тегов
RUN git clone https://github.com/freeswitch/spandsp.git /usr/local/src/spandsp

RUN git clone https://github.com/signalwire/freeswitch.git /usr/local/src/freeswitch -bv1.10.11

# Сборка SpandSP модуля
WORKDIR /usr/local/src/spandsp
RUN ./bootstrap.sh
RUN ./configure
RUN make
RUN make install

# Сборка Sofia SIP модуля
WORKDIR /usr/local/src/sofia
RUN ./bootstrap.sh
RUN ./configure
RUN make
RUN make install

RUN ldconfig 

# Сборка FreeSwitch с добавлением mod_callcenter
WORKDIR /usr/local/src/freeswitch 
RUN bash ./bootstrap.sh -j 
RUN sed -i -E '/mod_(signalwire|pgsql)/d' modules.conf 
RUN echo "applications/mod_callcenter" >> modules.conf 
RUN bash ./configure 
RUN sed -i -E 's/V18_MODE_5BIT_(4545|50)/V18_MODE_WEITBRECHT_5BIT_4545/g' src/mod/applications/mod_spandsp/mod_spandsp_dsp.c 
RUN sed -i -E 's/v18_init\((.*)\);/v18_init(\1, NULL, NULL);/g' src/mod/applications/mod_spandsp/mod_spandsp_dsp.c 
RUN sed -i 's/switch_channel_answer(member_channel);/\/\/ switch_channel_answer(member_channel);/' src/mod/applications/mod_callcenter/mod_callcenter.c
RUN make -j 
RUN make install 
RUN make cd-sounds-install 
RUN make cd-moh-install

# Копируем изначальные данные конфигурации
COPY config/conf /usr/local/freeswitch/conf
COPY config/scripts /usr/local/freeswitch/scripts
COPY config/sip-users/default.xml /usr/local/freeswitch/conf/directory/default.xml
RUN rm -f /usr/local/freeswitch/conf/autoload_configs/callcenter.conf.xml

# Добавляем скрипт для настройки паролей и IP
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Указываем команду для запуска скрипта
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
