#!/bin/sh
set -e
mkdir -p /var/run/apache2 /var/lock/apache2 /var/log/apache2
rm -f /var/run/apache2/apache2.pid
. /etc/apache2/envvars
exec apache2 -D FOREGROUND
