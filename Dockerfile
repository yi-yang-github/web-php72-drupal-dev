FROM php:7.2-apache-stretch
LABEL maintainer="yi-yang-github"

COPY config/php.ini /usr/local/etc/php/

# Essentials
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    apt-utils \
    zlibc zlib1g zlib1g-dev \
    bzip2 \
    zip \
    unzip \
    sudo \
    wget gnupg nano vim

# Enable MySQL
RUN apt-get update && apt-get install -y mysql-client
RUN docker-php-ext-install pdo_mysql

# Enable GD (with jpeg and freetype support)
RUN apt-get update \
    && apt-get install -y libgd2-xpm-dev* libfreetype6-dev libjpeg62-turbo-dev libpng-dev libz-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-install opcache \
    && docker-php-ext-install bcmath

RUN pecl install redis && docker-php-ext-enable redis

# Add Xdebug but not enabled it by default
RUN apt -qy install $PHPIZE_DEPS && pecl install xdebug-2.8.0
# RUN docker-php-ext-enable xdebug

# Copy fake SSL certs for dev site.
COPY ./config/ssl/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key
COPY ./config/ssl/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem

# Enable mod_expires
RUN a2enmod expires

# Enable mod_rewrite
RUN a2enmod rewrite

# Enable Proxy
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod ssl
RUN a2enmod headers

# Copy fake SSL certs for dev site.
COPY ./config/ssl/ssl-cert-snakeoil.key /etc/ssl/private/ssl-cert-snakeoil.key
COPY ./config/ssl/ssl-cert-snakeoil.pem /etc/ssl/certs/ssl-cert-snakeoil.pem


COPY ./config/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY ./config/sites-available/001-default-ssl.conf /etc/apache2/sites-available/001-default-ssl.conf

# enable the SSL dev site
RUN a2ensite 001-default-ssl

# Register the COMPOSER_HOME environment variable
ENV COMPOSER_HOME /composer

# Add global binary directory to PATH and make sure to re-export it
ENV PATH /composer/vendor/bin:$PATH

# Allow Composer to be run as root
ENV COMPOSER_ALLOW_SUPERUSER 1

# Setup the Composer installer
RUN curl -o /tmp/composer-setup.php https://getcomposer.org/installer \
  && curl -o /tmp/composer-setup.sig https://composer.github.io/installer.sig \
  && php -r "if (hash('SHA384', file_get_contents('/tmp/composer-setup.php')) !== trim(file_get_contents('/tmp/composer-setup.sig'))) { unlink('/tmp/composer-setup.php'); echo 'Invalid installer' . PHP_EOL; exit(1); }"

# Install Composer
RUN php /tmp/composer-setup.php --no-ansi --install-dir=/usr/local/bin --filename=composer --version=1.8.4 && rm -rf /tmp/composer-setup.php

# Display version information.
RUN composer --version

# Install Drush (PHP/Drupal)
RUN composer global require drush/drush:9.*


# Install node from nodesource, newer verion required by yarn installation.
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - \
 && apt-get install -y nodejs

# Add yarn (npm replacement)
# - Needs to have apt-transport-https otherwise will have build error.
RUN sudo apt install apt-transport-https
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
RUN sudo apt update && sudo apt install -y yarn
# Ensure it's installed
RUN yarn --version

# Add Cypress in Drupal dev, so we can run drush from cypress tests.
RUN yarn global add cypress --dev && which cypress
# Ensure it's installed
RUN cypress version

# FROM https://github.com/cypress-io/cypress-docker-images/blob/master/base/ubuntu16/Dockerfile
# Install Cypress dependencies (separate commands to avoid time outs)
RUN apt-get install -y \
    libgtk2.0-0
RUN apt-get install -y \
    libnotify-dev
RUN apt-get install -y \
    libgconf-2-4 \
    libnss3 \
    libxss1
RUN apt-get install -y \
    libasound2 \
    xvfb

WORKDIR /var/www


