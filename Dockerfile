FROM php:8.2-apache-bullseye

# Install PHP extensions
RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y git libfreetype6 libfreetype6-dev libjpeg62-turbo libjpeg62-turbo-dev libpng16-16 libpng-dev libpq5 libpq-dev libwebp6 libwebp-dev libxml2-dev libxslt1.1 libxslt-dev libzip-dev unzip uuid-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure zip --with-zip \
    && docker-php-ext-install -j$(nproc) exif gd intl mysqli opcache pgsql soap xsl zip \
    && pecl install apcu-5.1.23 redis-6.0.2 timezonedb-2023.3 uuid-1.2.0 \
    && docker-php-ext-enable apcu redis timezonedb uuid \
    && apt-get purge -y --auto-remove libfreetype6-dev libjpeg62-turbo-dev libpng-dev libpq-dev libwebp-dev libxml2-dev libxslt-dev uuid-dev \
    && rm -rf /tmp/pear /var/lib/apt/lists/*

# Install Moodle
COPY download-components /tmp/download-components
RUN --mount=type=secret,id=github-token \
    set -ex \
    && git config --global --add safe.directory /var/www/html \
    && GITHUB_TOKEN_FILE=/run/secrets/github-token /tmp/download-components /var/www/html \
    && rm /tmp/download-components \
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
