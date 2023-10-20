
FROM php:8.1-fpm AS release

# Get arguments
ARG INSTALL_DRUPAL_CONSOLE
ARG WEBAPP_SCRIPTS_PATH
ARG WWW_PATH_HOST=/var/www/html

# Composer settings
ENV DEBIAN_FRONTEND noninteractive
ENV COMPOSER_HOME /usr/local/lib/composer
ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_CACHE_DIR /dev/null

USER root

# always run apt update when start and after add new source list, then clean up at end.
RUN set -xe; \
    apt-get update -yqq && \
    pecl channel-update pecl.php.net && \
    apt-get install -yqq \
      apt-utils \
      gnupg2 \
      git \
      libzip-dev zip unzip && \
      docker-php-ext-configure zip && \
      docker-php-ext-install zip && \
      php -m | grep -q 'zip'

# Install dependencies
###########################################################################
RUN apt-get update -yqq && apt-get install --fix-missing -y \
    build-essential \
    nginx \
    gnupg2 \
    libpng-dev \
    libjpeg-dev \
    libpq-dev \
    zlib1g-dev \
    libzip-dev \
    libfreetype6-dev \
    libfreetype-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libldb-dev \
    libldap2-dev \
    libxml2-dev \
    libxslt-dev \
    libgmp-dev \
    libwebp-dev \
    nano \
    libicu-dev \
    tree

RUN apt-get update && apt-get install --fix-missing -y \
    libmcrypt-dev \
    postgresql-client \
    default-mysql-client

# Install PHP extensions
###########################################################################
RUN docker-php-ext-configure gd --with-jpeg --with-webp \
    && docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/ \
    && docker-php-ext-install -j$(nproc) gd  \
    zip  \
    ldap  \
    xsl \
    pgsql \
    mysqli \
    pdo_pgsql \
    pdo_mysql  \
    opcache


# BZ2:
###########################################################################
ARG INSTALL_BZ2=false
RUN if [ ${INSTALL_BZ2} = true ]; then \
  apt-get -yqq install libbz2-dev; \
  docker-php-ext-install bz2 \
;fi

# GMP (GNU Multiple Precision):
###########################################################################
ARG INSTALL_GMP=false
RUN if [ ${INSTALL_GMP} = true ]; then \
    # Install the GMP extension
	  apt-get install -yqq libgmp-dev && \
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "5" ]; then \
      ln -s /usr/include/x86_64-linux-gnu/gmp.h /usr/include/gmp.h \
    ;fi && \
    docker-php-ext-install gmp \
;fi

# XSL:
###########################################################################
ARG INSTALL_XSL=false
RUN if [ ${INSTALL_XSL} = true ]; then \
    # Install the xsl extension
    apt-get -y install libxslt-dev && \
    docker-php-ext-install xsl \
;fi

# pgsql
###########################################################################
ARG INSTALL_PGSQL=false
RUN if [ ${INSTALL_PGSQL} = true ]; then \
    # Install the pgsql extension
    docker-php-ext-install pgsql \
;fi


# pgsql client
###########################################################################
ARG INSTALL_PG_CLIENT=false
ARG INSTALL_POSTGIS=false
ARG PG_CLIENT_VERSION
RUN if [ ${INSTALL_PG_CLIENT} = true ]; then \
    apt-get install -yqq gnupg \
    && . /etc/os-release \
    && echo "deb http://apt.postgresql.org/pub/repos/apt $VERSION_CODENAME-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    && curl -sL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
    && apt-get update -yqq \
    && apt-get install -yqq postgresql-client-${PG_CLIENT_VERSION} postgis; \
    if [ ${INSTALL_POSTGIS} = true ]; then \
      apt-get install -yqq postgis; \
    fi \
    && apt-get purge -yqq gnupg \
;fi

# xDebug:
###########################################################################
ARG INSTALL_XDEBUG=false
ARG XDEBUG_PORT=9003
RUN if [ ${INSTALL_XDEBUG} = true ]; then \
  # Install the xdebug extension
  # https://xdebug.org/docs/compat
  if [ $(php -r "echo PHP_MAJOR_VERSION;") = "8" ] || { [ $(php -r "echo PHP_MAJOR_VERSION;") = "7" ] && { [ $(php -r "echo PHP_MINOR_VERSION;") = "4" ] || [ $(php -r "echo PHP_MINOR_VERSION;") = "3" ] ;} ;}; then \
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "8" ]; then \
      pecl install xdebug-3.2.1; \
    else \
      pecl install xdebug-3.1.6; \
    fi; \
  else \
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "5" ]; then \
      pecl install xdebug-2.5.5; \
    else \
      if [ $(php -r "echo PHP_MINOR_VERSION;") = "0" ]; then \
        pecl install xdebug-2.9.0; \
      else \
        pecl install xdebug-2.9.8; \
      fi \
    fi \
  fi && \
  docker-php-ext-enable xdebug \
;fi

# PHP REDIS EXTENSION
###########################################################################
ARG INSTALL_PHPREDIS=false
RUN if [ ${INSTALL_PHPREDIS} = true ]; then \
    # Install Php Redis Extension
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "5" ]; then \
      pecl install -o -f redis-4.3.0; \
    else \
      pecl install -o -f redis; \
    fi \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis \
;fi

# xlswriter:
###########################################################################
ARG INSTALL_XLSWRITER=false
RUN set -eux; \
    if [ ${INSTALL_XLSWRITER} = true ]; then \
      # Install Php xlswriter Extension \
      if [ $(php -r "echo PHP_MAJOR_VERSION;") != "5" ]; then \
          pecl install xlswriter  &&\
          docker-php-ext-enable xlswriter &&\
          php -m | grep -q 'xlswriter'; \
      else \
          echo "PHP Extension for xlswriter is not supported for PHP 5.0";\
      fi \
    ;fi

# pcntl
###########################################################################
ARG INSTALL_PCNTL=false
RUN if [ ${INSTALL_PCNTL} = true ]; then \
    # Installs pcntl, helpful for running Horizon
    docker-php-ext-install pcntl \
;fi

# bcmath:
###########################################################################

ARG INSTALL_BCMATH=false

RUN if [ ${INSTALL_BCMATH} = true ]; then \
    # Install the bcmath extension
    docker-php-ext-install bcmath \
;fi

# PHP Memcached:
###########################################################################
ARG INSTALL_MEMCACHED=false
RUN if [ ${INSTALL_MEMCACHED} = true ]; then \
    # Install the php memcached extension
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "5" ]; then \
      echo '' | pecl -q install memcached-2.2.0; \
    else \
      echo '' | pecl -q install memcached; \
    fi \
    && docker-php-ext-enable memcached \
;fi

# Exif:
###########################################################################
ARG INSTALL_EXIF=false
RUN if [ ${INSTALL_EXIF} = true ]; then \
    # Enable Exif PHP extentions requirements
    docker-php-ext-install exif \
;fi

# PHP OCI8:
###########################################################################

ARG INSTALL_OCI8=false
ARG ORACLE_INSTANT_CLIENT_MIRROR=https://github.com/the-paulus/oracle-instantclient/raw/master/
ARG ORACLE_INSTANT_CLIENT_ARCH=x86_64
ARG ORACLE_INSTANT_CLIENT_MAJOR=18
ARG ORACLE_INSTANT_CLIENT_MINOR=3

ENV ORACLE_INSTANT_CLIENT_VERSION=${ORACLE_INSTANT_CLIENT_MAJOR}_${ORACLE_INSTANT_CLIENT_MINOR}
ENV LD_LIBRARY_PATH="/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}"
ENV OCI_HOME="/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}"
ENV OCI_LIB_DIR="/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}"
ENV OCI_INCLUDE_DIR="/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/sdk/include"
ENV OCI_VERSION=${ORACLE_INSTANT_CLIENT_MAJOR}

RUN if [ ${INSTALL_OCI8} = true ]; then \
    # Install wget
    apt-get install --no-install-recommends -yqq wget \
    # Install Oracle Instantclient
    && mkdir /opt/oracle \
        && cd /opt/oracle \
        && wget ${ORACLE_INSTANT_CLIENT_MIRROR}instantclient-basic-linux.${ORACLE_INSTANT_CLIENT_ARCH}-${ORACLE_INSTANT_CLIENT_VERSION}.zip \
      && wget ${ORACLE_INSTANT_CLIENT_MIRROR}instantclient-sdk-linux.${ORACLE_INSTANT_CLIENT_ARCH}-${ORACLE_INSTANT_CLIENT_VERSION}.zip \
      && unzip /opt/oracle/instantclient-basic-linux.${ORACLE_INSTANT_CLIENT_ARCH}-${ORACLE_INSTANT_CLIENT_VERSION}.zip -d /opt/oracle \
      && unzip /opt/oracle/instantclient-sdk-linux.${ORACLE_INSTANT_CLIENT_ARCH}-${ORACLE_INSTANT_CLIENT_VERSION}.zip -d /opt/oracle \
      && if [ ${OCI_VERSION} -lt 18 ] ; then ln -s /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libclntsh.so.${ORACLE_INSTANT_CLIENT_MAJOR}.${ORACLE_INSTANT_CLIENT_MINOR} /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libclntsh.so ; fi\
      && if [ ${OCI_VERSION} -lt 18 ] ; then ln -s /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libclntshcore.so.${ORACLE_INSTANT_CLIENT_MAJOR}.${ORACLE_INSTANT_CLIENT_MINOR} /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libclntshcore.so ; fi \
      && if [ ${OCI_VERSION} -lt 18 ] ; then ln -s /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libocci.so.${ORACLE_INSTANT_CLIENT_MAJOR}.${ORACLE_INSTANT_CLIENT_MINOR} /opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/libocci.so ; fi \
        && rm -rf /opt/oracle/*.zip \
    # Install PHP extensions deps
    && apt-get install --no-install-recommends -yqq \
      libaio-dev \
      freetds-dev && \
    # Install PHP extensions
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "5" ]; then \
      echo 'instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/' | pecl install oci8-2.0.12; \
    elif [ $(php -r "echo PHP_MAJOR_VERSION;") = "7" ]; then \
      echo 'instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/' | pecl install oci8-2.2.0; \
    elif [ $(php -r "echo PHP_MAJOR_VERSION;") = "8" ] && [ $(php -r "echo PHP_MINOR_VERSION;") = "0" ]; then \
      echo "instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/" | pecl install oci8-3.0.1; \
    elif [ $(php -r "echo PHP_MAJOR_VERSION . PHP_MINOR_VERSION;") = "81" ]; then \
        echo "instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/" | pecl install oci8-3.2.1; \
    else \
      echo "instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION}/" | pecl install oci8; \
    fi \
    && docker-php-ext-configure pdo_oci --with-pdo-oci=instantclient,/opt/oracle/instantclient_${ORACLE_INSTANT_CLIENT_VERSION},${ORACLE_INSTANT_CLIENT_MAJOR}.${ORACLE_INSTANT_CLIENT_MINOR} \
        && docker-php-ext-configure pdo_dblib --with-libdir=/lib/x86_64-linux-gnu \
        && docker-php-ext-install \
                pdo_oci \
        && docker-php-ext-enable \
                oci8 \
  ;fi


# Opcache:
###########################################################################

ARG INSTALL_OPCACHE=false

RUN if [ ${INSTALL_OPCACHE} = true ]; then \
    docker-php-ext-install opcache \
;fi


# LDAP:
###########################################################################
ARG INSTALL_LDAP=false
RUN if [ ${INSTALL_LDAP} = true ]; then \
    apt-get install -yqq libldap2-dev && \
    ARCH=$(arch)   && \
    docker-php-ext-configure ldap --with-libdir="lib/${ARCH}-linux-gnu/" && \
    docker-php-ext-install ldap \
;fi


# Mysqli Modifications:
###########################################################################
ARG INSTALL_MYSQLI=false
RUN if [ ${INSTALL_MYSQLI} = true ]; then \
    docker-php-ext-install mysqli \
;fi

# ImageMagick:
###########################################################################
ARG INSTALL_IMAGEMAGICK=false
ARG IMAGEMAGICK_VERSION=latest
ENV IMAGEMAGICK_VERSION ${IMAGEMAGICK_VERSION}
RUN if [ ${INSTALL_IMAGEMAGICK} = true ]; then \
    apt-get update && \
    apt-get install -yqq libmagickwand-dev imagemagick && \
    if [ $(php -r "echo PHP_MAJOR_VERSION;") = "8" ]; then \
      cd /tmp && \
      if [ ${IMAGEMAGICK_VERSION} = "latest" ]; then \
        git clone https://github.com/Imagick/imagick; \
      else \
        git clone --branch ${IMAGEMAGICK_VERSION} https://github.com/Imagick/imagick; \
      fi && \
      cd imagick && \
      phpize && \
      ./configure && \
      make && \
      make install && \
      rm -r /tmp/imagick; \
    else \
      pecl install imagick; \
    fi && \
    docker-php-ext-enable imagick; \
    php -m | grep -q 'imagick' \
;fi

# IMAP:
###########################################################################
ARG INSTALL_IMAP=false
RUN if [ ${INSTALL_IMAP} = true ]; then \
    apt-get install -yqq libc-client-dev libkrb5-dev && \
    docker-php-ext-configure imap --with-kerberos --with-imap-ssl && \
    docker-php-ext-install imap \
;fi

# MySQL Client:
###########################################################################
ARG INSTALL_MYSQL_CLIENT=false
RUN if [ ${INSTALL_MYSQL_CLIENT} = true ]; then \
      apt-get -y install default-mysql-client \
;fi

# FFMPEG:
###########################################################################
ARG INSTALL_FFMPEG=false
RUN if [ ${INSTALL_FFMPEG} = true ]; then \
    apt-get update -y && \
    apt-get -y install ffmpeg \
;fi


# wkhtmltopdf:
#####################################
ARG INSTALL_WKHTMLTOPDF=false
ARG WKHTMLTOPDF_VERSION=0.12.6.1-3
RUN if [ ${INSTALL_WKHTMLTOPDF} = true ]; then \
    ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) \
    && apt-get install -yqq \
      libxrender1 \
      libfontconfig1 \
      libx11-dev \
      libjpeg62 \
      libxtst6 \
      fontconfig \
      libjpeg62-turbo \
      xfonts-base \
      xfonts-75dpi \
      wget \
    # && cat /etc/os-release \
    && if [ ${LARADOCK_PHP_VERSION} = "5.6" ] || \
        [ ${LARADOCK_PHP_VERSION} = "7.0" ]; then \
      wget "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.stretch_${ARCH}.deb"; \
      dpkg -i "wkhtmltox_0.12.6-1.stretch_${ARCH}.deb"; \
    elif [ ${LARADOCK_PHP_VERSION} = "7.1" ] || \
        [ ${LARADOCK_PHP_VERSION} = "7.2" ] || \
        [ ${LARADOCK_PHP_VERSION} = "7.3" ] || \
        [ ${LARADOCK_PHP_VERSION} = "7.4" ]; then \
      wget "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_${ARCH}.deb"; \
      dpkg -i "wkhtmltox_0.12.6-1.buster_${ARCH}.deb"; \
    elif [ ${LARADOCK_PHP_VERSION} = "8.0" ]; then \
      wget "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.bullseye_${ARCH}.deb"; \
      dpkg -i "wkhtmltox_${WKHTMLTOPDF_VERSION}.bullseye_${ARCH}.deb"; \
    else \
      wget "https://github.com/wkhtmltopdf/packaging/releases/download/${WKHTMLTOPDF_VERSION}/wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_${ARCH}.deb"; \
      dpkg -i "wkhtmltox_${WKHTMLTOPDF_VERSION}.bookworm_${ARCH}.deb"; \
    fi \
;fi

# XMLRPC:
###########################################################################
ARG INSTALL_XMLRPC=false
RUN if [ ${INSTALL_XMLRPC} = true ]; then \
  apt-get -yq install libxml2-dev; \
  if [ $(php -r "echo PHP_MAJOR_VERSION;") = "8" ]; then \
    pecl install xmlrpc-1.0.0RC3; \
    docker-php-ext-enable xmlrpc; \
  else \
    docker-php-ext-install xmlrpc; \
  fi \
;fi

# New Relic for PHP:
###########################################################################
ARG NEW_RELIC=${NEW_RELIC}
ARG NEW_RELIC_KEY=${NEW_RELIC_KEY}
ARG NEW_RELIC_APP_NAME=${NEW_RELIC_APP_NAME}
RUN if [ ${NEW_RELIC} = true ]; then \
  curl -L http://download.newrelic.com/php_agent/release/newrelic-php5-9.18.1.303-linux.tar.gz | tar -C /tmp -zx && \
  export NR_INSTALL_USE_CP_NOT_LN=1 && \
  export NR_INSTALL_SILENT=1 && \
  /tmp/newrelic-php5-*/newrelic-install install && \
  rm -rf /tmp/newrelic-php5-* /tmp/nrinstall* && \
  sed -i \
  -e 's/"REPLACE_WITH_REAL_KEY"/"'${NEW_RELIC_KEY}'"/' \
  -e 's/newrelic.appname = "PHP Application"/newrelic.appname = "'${NEW_RELIC_APP_NAME}'"/' \
  -e 's/;newrelic.daemon.app_connect_timeout =.*/newrelic.daemon.app_connect_timeout=15s/' \
  -e 's/;newrelic.daemon.start_timeout =.*/newrelic.daemon.start_timeout=5s/' \
  /usr/local/etc/php/conf.d/newrelic.ini \
;fi


# Install Drupal Console
###########################################################################
RUN if [ ${INSTALL_DRUPAL_CONSOLE} = true ]; then \
    apt-get -y install mysql-client && \
    curl https://drupalconsole.com/installer -L -o drupal.phar && \
    mv drupal.phar /usr/local/bin/drupal && \
    chmod +x /usr/local/bin/drupal \
;fi

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin -- --filename=composer
COPY --from=composer /usr/bin/composer /usr/bin/composer

USER root

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    rm -f /var/log/lastlog /var/log/faillog

# Configure non-root user.
ARG PUID=1000
ARG PGID=1000
ARG LOCALE=POSIX

ENV PUID ${PUID}
ENV PGID ${PGID}
ENV LC_ALL ${LOCALE}

# Set permissions
RUN groupmod -o -g ${PGID} www-data && \
    usermod -o -u ${PUID} -g www-data www-data
RUN chown -R www-data:www-data ${WWW_PATH_HOST}


# Set working directory
WORKDIR ${WWW_PATH_HOST}

COPY ./src /var/www/html

# Copy Nginx configuration
RUN rm -f /etc/nginx/sites-available/default
COPY config/default.conf /etc/nginx/sites-available/default

COPY start.sh /start.sh
RUN chmod +rx /start.sh

ENTRYPOINT ["/bin/bash"]

CMD ["/start.sh"]
