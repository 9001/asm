#!/bin/bash
set -e

# optimized-big;
# download+include some additional packages
# then remove some rarely useful kernel modules (drops wifi)
# and disable KMS when booting the final image

recommended_apks py3-requests ranger aria2
imshrink_filter_mods
nomodeset
