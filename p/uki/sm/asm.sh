#!/bin/ash
set -e

# secureboot has verified everything down through this file;
# now it's our job to verify the integrity of some.txt:

(cd $AR/sm; sha512sum -c <<'EOF'
77e7976f16e13fcf240d1b239ea01851360ea1d726cb9890da7c51d7dd2364b2c5ddfe9f7da1a08d339685021997a2fd347e3bd263578d3c4bfc7b86dbf4142e  some.txt
EOF
) || { printf '\033[31m\nABORT: resource integrity check failed\n\033[0m'; exit 1; }

printf '\n\033[32m  success!  celebratory shell:\033[0m\n\n'

exec /bin/ash -li
