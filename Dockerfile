FROM alpine:3.17.0

LABEL maintainer="Nginx FastDFS PHP Docker Maintainers <lirongtong@hotmail.com>"

ENV NGINX_VERSION=1.22.1 \
    NGINX_HTTP_PORT=80 \
    NGINX_HTTPS_PORT=443

ENV FASTDFS_STORAGE_HTTP_PORT=8888 \
    FASTDFS_STORAGE_PORT=23000 \
    FASTDFS_TRACKER_PORT=22122 \
    FASTDFS_VERSION=6.09

ENV PHPIZE_DEPS \
    autoconf \
    dpkg-dev dpkg \
    file \
    g++ \
    gcc \
    libc-dev \
    make \
    pkgconf \
    re2c

ENV PHP_VERSION 8.2.0

ENV REDIS_VERSION 5.3.7

ENV PHP_PORT=9000 \
    PHP_AMQP_VERSION=1.11.0 \
    PHP_INI_DIR=/usr/local/etc/php \
    PHP_CFLAGS="-fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64" \
    PHP_CPPFLAGS="$PHP_CFLAGS" \
    PHP_LDFLAGS="-Wl,-O1 -Wl,--hash-style=both -pie" \
    PHP_URL="https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz" \
    PHP_ASC_URL="https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz.asc" \
    PHP_MD5="" \
    PHP_SHA256="6ea4c2dfb532950fd712aa2a08c1412a6a81cd1334dd0b0bf88a8e44c2b3a943"

ENV GPG_KEYS E60913E4DF209907D8E30D96659A97C9CF2A795A 39B641343D8C104B2B146DC3F9C39DC0B9698544 1198C0117593497A5EC5C199286AF1F9897469DC 
ENV PHP_EXTRA_CONFIGURE_ARGS --enable-fpm --with-fpm-user=www-data --with-fpm-group=www-data --disable-cgi

COPY conf/client.conf /etc/fdfs/
COPY conf/http.conf /etc/fdfs/
COPY conf/mime.types /etc/fdfs/
COPY conf/storage.conf /etc/fdfs/
COPY conf/tracker.conf /etc/fdfs/
COPY conf/mod_fastdfs.conf /etc/fdfs/
COPY docker-php-source /usr/local/bin/
COPY docker-php-ext-* /usr/local/bin/
COPY start.sh /home/

RUN set -eux; \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories; \
    \
    addgroup -g 101 -S nginx; \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx; \
    adduser -u 82 -D -S www-data -G www-data; \
    \
    # ---------------------------
    # --- *** --- php --- *** ---
    # ---------------------------
    \
    apk add --no-cache \
    ca-certificates \
    curl \
    tar \
    xz \
    bash \
    pcre-dev \
    zlib-dev \
    git \
    openssl; \
    \
    mkdir -p "$PHP_INI_DIR/conf.d"; \
    [ ! -d /var/www/html ]; \
    mkdir -p /var/www/html; \
    chown www-data:www-data /var/www/html; \
    chmod 777 /var/www/html; \
    chmod u+x /home/start.sh; \
    chmod u+x /usr/local/bin/docker-php-ext-enable; \
    chmod u+x /usr/local/bin/docker-php-ext-*; \
    chmod u+x /usr/local/bin/docker-php-source; \
    \
    apk add --no-cache --virtual .fetch-deps gnupg; \
    \
    mkdir -p /usr/src/build-deps; \
    cd /usr/src; \
    \
    curl -fsSL -o php.tar.xz "$PHP_URL"; \
    \
    if [ -n "$PHP_SHA256" ]; then \
    echo "$PHP_SHA256 *php.tar.xz" | sha256sum -c -; \
    fi; \
    if [ -n "$PHP_MD5" ]; then \
    echo "$PHP_MD5 *php.tar.xz" | md5sum -c -; \
    fi; \
    \
    if [ -n "$PHP_ASC_URL" ]; then \
    curl -fsSL -o php.tar.xz.asc "$PHP_ASC_URL"; \
    export GNUPGHOME="$(mktemp -d)"; \
    for key in $GPG_KEYS; do \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
    done; \
    gpg --batch --verify php.tar.xz.asc php.tar.xz; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME"; \
    fi; \
    \
    apk del --no-network .fetch-deps; \
    \
    apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    argon2-dev \
    coreutils \
    curl-dev \
    libedit-dev \
    libsodium-dev \
    libxml2-dev \
    openssl-dev \
    sqlite-dev \
    linux-headers \
    oniguruma-dev \
    libxslt-dev \
    gd-dev \
    cmake \
    geoip-dev \
    perl-dev \
    libedit-dev \
    mercurial \
    alpine-sdk \
    findutils; \
    \
    export CFLAGS="$PHP_CFLAGS" \
    CPPFLAGS="$PHP_CPPFLAGS" \
    LDFLAGS="$PHP_LDFLAGS"; \
    \
    docker-php-source extract; \
    cd /usr/src/php; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    ./configure \
    --build="$gnuArch" \
    --with-config-file-path="$PHP_INI_DIR" \
    --with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
    --enable-option-checking=fatal \
    --with-mhash \
    --enable-sockets \
    --enable-ftp \
    --enable-mbstring \
    --enable-mysqlnd \
    --enable-bcmath \
    --with-mysqli \
    --with-pdo-mysql \
    --with-password-argon2 \
    --with-sodium=shared \
    --with-pdo-sqlite=/usr \
    --with-sqlite3=/usr \
    --with-curl \
    --with-libedit \
    --with-openssl \
    --with-zlib \
    --with-pear \
    $(test "$gnuArch" = 's390x-linux-musl' && echo '--without-pcre-jit') \
    ${PHP_EXTRA_CONFIGURE_ARGS:-}; \
    \
    make -j "$(nproc)"; \
    find -type f -name '*.a' -delete; \
    make install; \
    find /usr/local/bin /usr/local/sbin -type f -perm +0111 -exec strip --strip-all '{}' + || true; \
    make clean; \
    \
    cp -v php.ini-* "$PHP_INI_DIR/"; \
    mv ${PHP_INI_DIR}/php.ini-production ${PHP_INI_DIR}/php.ini; \
    \
    cd /; \
    docker-php-source delete; \
    \
    runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
    | tr ',' '\n' \
    | sort -u \
    | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache $runDeps; \
    \
    pecl update-channels; \
    rm -rf /tmp/pear ~/.pearrc; \
    php --version; \
    \
    docker-php-ext-enable sodium; \
    \
    cd /usr/local/etc; \
    if [ -d php-fpm.d ]; then \
    sed 's!=NONE/!=!g' php-fpm.conf.default | tee php-fpm.conf > /dev/null; \
    cp php-fpm.d/www.conf.default php-fpm.d/www.conf; \
    else \
    mkdir php-fpm.d; \
    cp php-fpm.conf.default php-fpm.d/www.conf; \
    { \
    echo '[global]'; \
    echo 'include=etc/php-fpm.d/*.conf'; \
    } | tee php-fpm.conf; \
    fi; \
    { \
    echo '[global]'; \
    echo 'error_log = /proc/self/fd/2'; \
    echo; echo '; https://github.com/docker-library/php/pull/725#issuecomment-443540114'; echo 'log_limit = 8192'; \
    echo; \
    echo '[www]'; \
    echo '; if we send this to /proc/self/fd/1, it never appears'; \
    echo 'access.log = /proc/self/fd/2'; \
    echo; \
    echo 'clear_env = no'; \
    echo; \
    echo '; Ensure worker stdout and stderr are sent to the main error log.'; \
    echo 'catch_workers_output = yes'; \
    echo 'decorate_workers_output = no'; \
    } | tee php-fpm.d/docker.conf; \
    { \
    echo '[global]'; \
    echo 'daemonize = no'; \
    echo; \
    echo '[www]'; \
    echo 'listen = 9000'; \
    } | tee php-fpm.d/zz-docker.conf; \
    \
    # --------------------------------
    # --- *** --- pngquant --- *** ---
    # --------------------------------
    wget https://github.com/kornelski/pngquant/archive/master.tar.gz -O pngquant.tar.gz; \
    tar zxf pngquant.tar.gz; \
    cd ./pngquant-main; \
    ./configure && make && make install; \
    \
    # -------------------------------------
    # --- *** --- libfastcommon --- *** ---
    # -------------------------------------
    cd /usr/src/build-deps; \
    wget https://github.com/happyfish100/libfastcommon/archive/master.tar.gz -O libfastcommon.tar.gz; \
    tar zxf libfastcommon.tar.gz; \
    cd ./libfastcommon-master; \
    ./make.sh; \
    ./make.sh install; \
    \
    # --------------------------------------
    # --- *** --- libserverframe --- *** ---
    # --------------------------------------
    cd /usr/src/build-deps; \
    wget https://github.com/happyfish100/libserverframe/archive/master.tar.gz -O libserverframe.tar.gz; \
    tar zxf libserverframe.tar.gz; \
    cd ./libserverframe-master; \
    ./make.sh; \
    ./make.sh install; \
    \
    # -------------------------------
    # --- *** --- fastdfs --- *** ---
    # -------------------------------
    cd /usr/src/build-deps; \
    wget https://github.com/happyfish100/fastdfs/archive/refs/tags/V${FASTDFS_VERSION}.tar.gz -O fastdfs-${FASTDFS_VERSION}.tar.gz; \
    chmod u+x fastdfs-${FASTDFS_VERSION}.tar.gz; \
    tar zxf fastdfs-${FASTDFS_VERSION}.tar.gz; \
    cd ./fastdfs-${FASTDFS_VERSION}; \
    ./make.sh; \
    ./make.sh install; \
    \
    # -----------------------------------
    # --- *** --- php fastdfs --- *** ---
    # -----------------------------------
    cd ./php_client; \
    /usr/local/bin/phpize; \
    ./configure --with-php-config=/usr/local/bin/php-config; \
    make; \
    make install; \
    cat ./fastdfs_client.ini >> ${PHP_INI_DIR}/php.ini; \
    \
    # ----------------------------------
    # --- *** --- rabbitmq-c --- *** ---
    # ----------------------------------
    cd /usr/src/build-deps; \
    wget https://github.com/alanxz/rabbitmq-c/archive/master.tar.gz -O rabbitmq-c.tar.gz; \
    tar zxvf rabbitmq-c.tar.gz; \
    cd ./rabbitmq-c-master; \
    mkdir build && cd build; \
    cmake ..; \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local/librabbitmq ..; \
    cmake --build . --target install; \
    ln -s /usr/local/librabbitmq/lib64 /usr/local/librabbitmq/lib; \
    \
    # --------------------------------
    # --- *** --- php amqp --- *** ---
    # --------------------------------
    cd /usr/src/build-deps; \
    wget http://pecl.php.net/get/amqp-${PHP_AMQP_VERSION}.tgz; \
    tar zxf amqp-${PHP_AMQP_VERSION}.tgz; \
    cd amqp-${PHP_AMQP_VERSION}; \
    /usr/local/bin/phpize; \
    ./configure --with-php-config=/usr/local/bin/php-config --with-amqp --with-librabbitmq-dir=/usr/local/librabbitmq; \
    make && make install; \
    echo extension=amqp >> ${PHP_INI_DIR}/php.ini; \
    \
    # ---------------------------------
    # --- *** --- php redis --- *** ---
    # ---------------------------------
    cd /usr/src/build-deps; \
    wget https://pecl.php.net/get/redis-${REDIS_VERSION}.tgz; \
    tar zxf redis-${REDIS_VERSION}.tgz; \
    cd ./redis-${REDIS_VERSION}; \
    /usr/local/bin/phpize; \
    ./configure --with-php-config=/usr/local/bin/php-config; \
    make; \
    make install; \
    echo extension=redis >> ${PHP_INI_DIR}/php.ini; \
    \
    # --------------------------------
    # --- *** --- composer --- *** ---
    # --------------------------------
    cd /usr/src/build-deps; \
    curl -sS https://getcomposer.org/installer | php; \
    mv composer.phar /usr/local/bin/composer; \
    composer -v; \
    composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/; \
    \
    # --------------------------------------------------
    # --- *** --- nginx/fastdfs-nginx-module --- *** ---
    # --------------------------------------------------
    cd /usr/src/build-deps; \
    wget https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -O nginx-${NGINX_VERSION}.tar.gz; \
    wget https://github.com/happyfish100/fastdfs-nginx-module/archive/master.tar.gz -O fastdfs-nginx-module.tar.gz; \
    tar zxf fastdfs-nginx-module.tar.gz; \
    chmod u+x ./fastdfs-nginx-module-master/src/config; \
    tar zxf nginx-${NGINX_VERSION}.tar.gz; \
    mkdir -p /var/cache/nginx; \
    cd ./nginx-${NGINX_VERSION}; \
    ./configure \
    --prefix=/etc/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/nginx/modules \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --http-log-path=/var/log/nginx/access.log \
    --pid-path=/var/run/nginx.pid \
    --lock-path=/var/run/nginx.lock \
    --http-client-body-temp-path=/var/cache/nginx/client_temp \
    --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
    --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
    --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
    --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
    --user=nginx \
    --group=nginx \
    --with-compat \
    --with-file-aio \
    --with-threads \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_mp4_module \
    --with-http_random_index_module \
    --with-http_realip_module \
    --with-http_secure_link_module \
    --with-http_slice_module \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_sub_module \
    --with-http_v2_module \
    --with-mail \
    --with-mail_ssl_module \
    --with-stream \
    --with-stream_realip_module \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-${NGINX_VERSION}/debian/debuild-base/nginx-${NGINX_VERSION}=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
    --add-module=/usr/src/build-deps/fastdfs-nginx-module-master/src; \
    make; \
    make install; \
    nginx -V; \
    \
    apk del --no-network .build-deps; \
    rm -rf /usr/src/build-deps

EXPOSE ${NGINX_HTTP_PORT} ${NGINX_HTTPS_PORT} ${FASTDFS_STORAGE_HTTP_PORT} ${FASTDFS_STORAGE_PORT} ${FASTDFS_TRACKER_PORT} ${PHP_PORT}

STOPSIGNAL SIGTERM

ENTRYPOINT ["/home/start.sh"]
