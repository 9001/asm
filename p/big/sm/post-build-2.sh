#!/bin/bash
set -e

# download+include some additional packages
# and disable KMS when booting the final image

recommended_apks py3-requests ranger aria2
nomodeset
