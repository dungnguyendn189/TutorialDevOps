#!/usr/bin/env
set -e

/usr/local/sbin/php-fpm &
/usr/sbin/nginx -g "daemon off;"
