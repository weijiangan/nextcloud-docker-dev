# Stage 1: Build nc-server (Rust)
FROM rust:1.89-slim AS nc-server-builder

RUN apt update && apt-get install -y --no-install-recommends \
    git \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy only the root Cargo manifests first to leverage Docker layer caching.
# Workspace members (crates/*) are intentionally NOT copied here — cargo's resolver
# v2 warns and skips missing members, so the dummy build below only compiles deps.
COPY nc-server-core/core-rs/Cargo.toml nc-server-core/core-rs/Cargo.lock ./

# Create dummy binary at workspace root to force cargo to download & compile all
# dependencies. --mount=type=cache persists cargo registry and target/ across
# rebuilds even when the COPY layers above are invalidated.
RUN --mount=type=cache,target=/usr/local/cargo/registry,id=cargo-registry \
    --mount=type=cache,target=/build/target,id=cargo-target \
    mkdir -p src && echo 'fn main() {}' > src/main.rs && \
    cargo fetch && \
    cargo build --release && \
    rm -rf src target/release/nc-server 2>/dev/null || true

# Copy php-shim (needed at runtime)
COPY nc-server-core/core-rs/php-shim/ ./php-shim/

# Copy full source - this layer invalidates when your code changes
COPY nc-server-core/core-rs/ .

# Real build - cache mounts keep compiled deps even when source changes, so only
# your modified code is recompiled (typically seconds instead of minutes).
# Copy the binary out of the cache mount into the image layer for COPY --from.
RUN --mount=type=cache,target=/usr/local/cargo/registry,id=cargo-registry \
    --mount=type=cache,target=/build/target,id=cargo-target \
    cargo build --release && \
    cp target/release/nc-server /build/nc-server

# Stage 2: Main PHP-FPM image
FROM php:8.4-fpm

ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

RUN chmod +x /usr/local/bin/install-php-extensions

RUN install-php-extensions \
    apcu \
    bcmath \
    excimer \
    exif \
    gd \
    gmp \
    intl \
    ldap \
    memcached \
    oci8 \
    opcache \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    redis \
    smbclient \
    sysvsem \
    xdebug \
    zip \
    blackfire \
    @composer

# dev tools separate install so we quickly change without rebuilding all php extensions
RUN apt update && apt-get install -y --no-install-recommends \
    git \
    curl \
    vim-tiny \
    nano \
    sudo \
    cron \
    smbclient \
    iproute2 \
    lnav \
    wget \
    iputils-ping \
    gnupg2 \
    jq \
    ripgrep \
    rsync \
    && rm -rf /var/lib/apt/lists/*

# Install PHPUnit
RUN wget -O /usr/local/bin/phpunit11 https://phar.phpunit.de/phpunit-11.phar \
    && chmod +x /usr/local/bin/phpunit11 \
    && wget -O /usr/local/bin/phpunit12 https://phar.phpunit.de/phpunit-12.phar \
    && chmod +x /usr/local/bin/phpunit12 \
    && ln -s /usr/local/bin/phpunit11 /usr/local/bin/phpunit

# Install NVM
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash \
    && export NVM_DIR="/root/.nvm" \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install node \
    && nvm alias default node \
    && nvm cache clear

RUN wget https://gist.githubusercontent.com/nickvergessen/e21ee0a09ee3b3f7fd1b04c83dd3e114/raw/83142be1e50c23e8de1bd7aae88a95e5d6ae1ce2/nextcloud_log.json && lnav -i nextcloud_log.json && rm nextcloud_log.json

RUN { \
        echo '[global]'; \
        echo 'client min protocol = SMB2'; \
        echo 'client max protocol = SMB3'; \
        echo 'hide dot files = no'; \
} > /etc/samba/smb.conf

RUN mkdir --parent /var/log/cron
ADD configs/cron.conf /etc/nc-cron.conf
RUN crontab /etc/nc-cron.conf

ADD configs/php/nextcloud.ini /usr/local/etc/php/conf.d/nextcloud.ini
ADD configs/php/xdebug.ini /usr/local/etc/php/conf.d/xdebug.ini

# Setup blackfire probe
RUN mv /usr/local/etc/php/conf.d/docker-php-ext-blackfire.ini /usr/local/etc/php/conf.d/docker-php-ext-blackfire.ini.disabled

VOLUME /var/www/html
VOLUME /var/www/html/apps-writable
VOLUME /var/www/html/config
VOLUME /var/www/html/data

ENV SQL=sqlite
ENV NEXTCLOUD_AUTOINSTALL=YES
ENV WITH_REDIS=NO

ENV WEBROOT=/var/www/html
WORKDIR /var/www/html

# Ensure PHP-FPM socket directory exists and configure socket listening
RUN install -d -o www-data -g www-data /run/php
ADD php84/configs/php/zzz-nextcloud.conf /usr/local/etc/php-fpm.d/zzz-nextcloud.conf

# Copy nc-server binary and php-shim from builder
COPY --from=nc-server-builder /build/nc-server /usr/local/bin/nc-server
COPY --from=nc-server-builder /build/php-shim/index.php /usr/local/share/nc-server/php-shim/index.php

# Allow nc-server to bind port 80 when running as www-data.
RUN setcap 'cap_net_bind_service=+ep' /usr/local/bin/nc-server

# Set defaults for nc-server FastCGI configuration
ENV NC_FASTCGI_SOCKET=/run/php/php-fpm.sock
ENV NC_PHP_SHIM=/usr/local/share/nc-server/php-shim/index.php

ENTRYPOINT  ["/usr/local/bin/bootstrap.sh"]
CMD ["php-fpm"]

ADD data/installing.html /root/installing.html
ADD configs/autoconfig_mysql.php configs/autoconfig_pgsql.php configs/autoconfig_oci.php configs/default.config.php configs/redis.config.php configs/apcu.config.php /root/
ADD bin/bootstrap.sh bin/occ /usr/local/bin/
