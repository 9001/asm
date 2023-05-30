#!/bin/ash
set -e

# secureboot has verified everything down through this file;
# now it's our job to verify the integrity of some.txt:

(cd $AR/sm; sha512sum -c <<'EOF'
77e7976f16e13fcf240d1b239ea01851360ea1d726cb9890da7c51d7dd2364b2c5ddfe9f7da1a08d339685021997a2fd347e3bd263578d3c4bfc7b86dbf4142e  some.txt
EOF
) || { printf '\033[31m\nABORT: resource integrity check failed\n\033[0m'; exit 1; }

##
## if secureboot is in setup mode, install our own certs
## (remember to add the certs to the sha512sum check above)

install_secureboot_certs() {
    e="cannot install secureboot certs"

    [ -e "$AR/certs/pk.auth" ] &&
    [ -e "$AR/certs/kek.auth" ] &&
    [ -e "$AR/certs/db.auth" ] || {
        echo could not find secureboot certs to install
        return
    }
    apka -q mokutil efitools || {
        echo "$e; could not install mokutil and efitools"
        return
    }
    mokutil --sb-state | grep -q Setup || {
        mokutil --sb-state | grep -q "SecureBoot enabled" && {
            echo secureboot is already locked down
            return
        }
        echo "$e; uefi is not in secureboot setup mode"
        return
    }
    echo installing secureboot certs
    chattr -i /sys/firmware/efi/efivars/*
    efi-updatevar -f $AR/certs/db.auth db
    efi-updatevar -f $AR/certs/kek.auth KEK
    efi-updatevar -f $AR/certs/pk.auth PK  # keep last
    mokutil --sb-state | grep -q Setup &&
        log 'WARNING: secureboot did not leave setup mode' ||
        echo 'secureboot was configured successfully'
}
install_secureboot_certs

printf '\n\033[32m  success!  celebratory shell:\033[0m\n\n'

exec /bin/ash -li
