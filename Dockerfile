# ==================================================
# Laravel Base Image (Alpine)
# PHP + Octane + Swoole + Redis
# MySQL + PostgreSQL
# ==================================================

FROM php:8.4-fpm-alpine

LABEL maintainer="Ismael <ismael@elrincondeisma.com>"

# ==================================================
# System dependencies
# ==================================================
RUN apk add --no-cache \
    bash \
    git \
    curl \
    zip \
    unzip \
    supervisor \
    icu-dev \
    libxml2-dev \
    oniguruma-dev \
    postgresql-dev \
    mariadb-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    linux-headers \
    nodejs \
    npm

# ==================================================
# PHP Extensions
# ==================================================
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        mbstring \
        exif \
        pcntl \
        bcmath \
        intl \
        gd \
        opcache

# ==================================================
# Redis extension
# ==================================================
RUN pecl install redis \
    && docker-php-ext-enable redis

# ==================================================
# Swoole (Octane)
# ==================================================
RUN pecl install swoole \
    && docker-php-ext-enable swoole

# ==================================================
# Composer
# ==================================================
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ==================================================
# PHP config
# ==================================================
COPY php.ini /usr/local/etc/php/php.ini

# ==================================================
# Non-root user
# ==================================================
RUN addgroup -g 1000 laravel \
    && adduser -G laravel -g laravel -s /bin/sh -D laravel

WORKDIR /var/www

RUN chown -R laravel:laravel /var/www

USER laravel

EXPOSE 8000 9000

CMD ["php-fpm"]
