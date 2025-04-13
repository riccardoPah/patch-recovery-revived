#!/bin/bash

####################################
# Copyright (c) [2025] [@ravindu644]
####################################

set -e -x

export WDIR="$(pwd)"
export RECOVERY_LINK="$1"
mkdir -p "${WDIR}/recovery"

# Clean-up is required
rm -rf "${WDIR}/recovery/"*

# Define magiskboot and signing key paths
AVB_KEY="${WDIR}/signing-keys/testkey_rsa2048.pem"
MAGISKBOOT="${WDIR}/binaries/magiskboot"

# Downloading/copying the recovery
download_recovery(){
    if [[ "${RECOVERY_LINK}" =~ ^https?:// ]]; then
    curl -L "${RECOVERY_LINK}" -o "${WDIR}/recovery/$(basename "${RECOVERY_LINK}")"
    elif [ -f "${RECOVERY_LINK}" ]; then
    cp "${RECOVERY_LINK}" "${WDIR}/recovery/"
    else
    echo -e "Invalid input: not a URL or file.\n"
    echo -e "If you entered a URL, make sure it begins with 'http://' or 'https://'"
    exit 1
    fi
}

# Check if the downloaded/copied file an archive
unarchive_recovery(){
    cd "${WDIR}/recovery/"
    local FILE=$(ls)
    [[ "$FILE" == *.zip ]] && unzip "$FILE" && rm "$FILE"
    [[ "$FILE" == *.lz4 ]] && lz4 -d "$FILE" "${FILE%.lz4}" && rm "$FILE"
    mv "$(ls *.img)" "recovery.img"
    cd "${WDIR}/"
}
