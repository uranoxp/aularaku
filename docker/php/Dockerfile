FROM alpine:3.20 AS moodle-source

ARG MOODLE_GIT_REF=MOODLE_502_STABLE

RUN apk add --no-cache git \
    && git clone --branch "${MOODLE_GIT_REF}" --depth 1 https://github.com/moodle/moodle.git /src/moodle

FROM php:8.3-fpm-alpine AS php-runtime

ARG MOODLE_GIT_REF=MOODLE_502_STABLE

RUN apk add --no-cache \
      bash \
      fcgi \
      freetype \
      gettext \
      icu-libs \
      libjpeg-turbo \
      libpng \
      libxml2 \
      libzip \
      mariadb-client \
      rsync \
      redis \
      su-exec \
      tzdata \
    && apk add --no-cache --virtual .build-deps \
      ${PHPIZE_DEPS} \
      curl-dev \
      freetype-dev \
      icu-dev \
      libjpeg-turbo-dev \
      libpng-dev \
      libsodium-dev \
      libxml2-dev \
      libzip-dev \
      linux-headers \
      oniguruma-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
      exif \
      gd \
      intl \
      mysqli \
      opcache \
      pdo \
      pdo_mysql \
      soap \
      sodium \
      zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && apk del .build-deps \
    && rm -rf /tmp/pear

COPY --from=moodle-source /src/moodle /opt/moodle-dist
COPY docker/php/entrypoint.sh /usr/local/bin/moodle-entrypoint
COPY docker/php/seed-code.sh /usr/local/bin/moodle-seed-code
COPY docker/php/sync-core.sh /usr/local/bin/moodle-sync-core
COPY docker/php/code-version.sh /usr/local/bin/moodle-code-version
COPY docker/php/moodle.crontab /etc/crontabs/root
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

RUN mkdir -p /var/www/moodle /var/www/moodle-state /var/www/moodledata \
    && chown -R www-data:www-data /opt/moodle-dist /var/www/moodle /var/www/moodle-state /var/www/moodledata \
    && chmod +x /usr/local/bin/moodle-entrypoint /usr/local/bin/moodle-seed-code /usr/local/bin/moodle-sync-core /usr/local/bin/moodle-code-version

WORKDIR /var/www/moodle

ENTRYPOINT ["moodle-entrypoint"]
CMD ["php-fpm", "-F"]

FROM nginx:1.27-alpine AS nginx-runtime

ARG MOODLE_GIT_REF=MOODLE_502_STABLE

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

WORKDIR /var/www/moodle
