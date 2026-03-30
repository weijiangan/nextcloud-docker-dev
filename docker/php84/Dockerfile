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
    nginx \
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

# Configure nginx
RUN mkdir -p /var/log/nginx && \
    chown -R www-data:www-data /var/log/nginx && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

ADD php84/configs/nginx/nextcloud.conf /etc/nginx/sites-available/nextcloud
RUN ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/nextcloud && \
    rm -f /etc/nginx/sites-enabled/default

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

ENTRYPOINT  ["/usr/local/bin/bootstrap.sh"]
CMD ["php-fpm"]

ADD data/installing.html /root/installing.html
ADD configs/autoconfig_mysql.php configs/autoconfig_pgsql.php configs/autoconfig_oci.php configs/default.config.php configs/redis.config.php configs/apcu.config.php /root/
ADD bin/bootstrap.sh bin/occ /usr/local/bin/
