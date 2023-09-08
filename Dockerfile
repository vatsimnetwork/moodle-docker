FROM php:8.2-apache-bullseye

ARG MOODLE_LMS_TAG=v4.2.2
ARG MOODLE_ATTO_MOREFONTCOLORS_TAG=2021062100
ARG MOODLE_MOD_CUSTOMCERT_TAG=v4.2.2
ARG MOODLE_TOOL_FORCEDCACHE_COMMIT=7f7e90b

# Install PHP extensions
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y git libfreetype6 libfreetype6-dev libjpeg62-turbo libjpeg62-turbo-dev libpng16-16 libpng-dev libwebp6 libwebp-dev libxml2-dev libxslt1.1 libxslt-dev libzip-dev unzip uuid-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure zip --with-zip \
    && docker-php-ext-install -j$(nproc) exif gd intl mysqli opcache soap xsl zip \
    && pecl install apcu-5.1.22 redis-5.3.7 timezonedb-2023.3 uuid-1.2.0 \
    && docker-php-ext-enable apcu redis timezonedb uuid \
    && apt-get purge -y --auto-remove git libfreetype6-dev libjpeg62-turbo-dev libpng-dev libwebp-dev libxml2-dev libxslt-dev uuid-dev \
    && rm -rf /tmp/pear /var/lib/apt/lists/*

# Install Moodle
RUN set -ex \
    && curl -L https://github.com/moodle/moodle/archive/refs/tags/${MOODLE_LMS_TAG}.tar.gz | tar -C /var/www/html --strip-components=1 -xz \
    && mkdir -p /var/www/html/lib/editor/atto/plugins/morefontcolors \
    && curl -L https://github.com/ndunand/moodle-atto_morefontcolors/archive/refs/tags/${MOODLE_ATTO_MOREFONTCOLORS_TAG}.tar.gz | tar -C /var/www/html/lib/editor/atto/plugins/morefontcolors --strip-components=1 -xz \
    && mkdir -p /var/www/html/mod/customcert \
    && curl -L https://github.com/mdjnelson/moodle-mod_customcert/archive/refs/tags/${MOODLE_MOD_CUSTOMCERT_TAG}.tar.gz | tar -C /var/www/html/mod/customcert --strip-components=1 -xz \
    && mkdir -p /var/www/html/admin/tool/forcedcache \
    && curl -L https://github.com/catalyst/moodle-tool_forcedcache/archive/${MOODLE_TOOL_FORCEDCACHE_COMMIT}.tar.gz | tar -C /var/www/html/admin/tool/forcedcache --strip-components=1 -xz \
    && chown -R www-data:www-data /var/www/html

# Apply page_compression.patch (MDL-69196)
COPY page_compression.patch /tmp/page_compression.patch
RUN set -ex \
    && cd /var/www/html \
    && patch -p1 < /tmp/page_compression.patch \
    && rm /tmp/page_compression.patch

# Configure PHP/Apache
COPY php.ini /usr/local/etc/php/php.ini
COPY moodle.conf /etc/apache2/sites-available/moodle.conf
RUN set -ex \
    && a2disconf docker-php other-vhosts-access-log serve-cgi-bin \
    && a2dissite 000-default \
    && a2enmod rewrite \
    && a2ensite moodle

# Configure Moodle
WORKDIR /var/www/html
COPY config.php /var/www/html/config.php
RUN set -ex \
    && php admin/cli/alternative_component_cache.php --rebuild

# CMD and ENTRYPOINT are inherited from the Apache image
