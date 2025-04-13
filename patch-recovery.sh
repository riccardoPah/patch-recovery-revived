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

    export RECOVERY_FILE="${WDIR}/recovery/recovery.img"
}

# Extract recovery.img
extract_recovery_image(){
    cd "${WDIR}/unpacked/"
	${MAGISKBOOT} unpack ${RECOVERY_FILE}
	${MAGISKBOOT} cpio ramdisk.cpio extract
    cd "${WDIR}/"
}

# Hex patch the "recovery" binary to get fastbootd mode back
hexpatch_recovery_image(){
    cd "${WDIR}/unpacked/"

	${MAGISKBOOT} hexpatch system/bin/recovery e10313aaf40300aa6ecc009420010034 e10313aaf40300aa6ecc0094 # 20 01 00 35
	${MAGISKBOOT} hexpatch system/bin/recovery eec3009420010034 eec3009420010035
	${MAGISKBOOT} hexpatch system/bin/recovery 3ad3009420010034 3ad3009420010035
	${MAGISKBOOT} hexpatch system/bin/recovery 50c0009420010034 50c0009420010035
	${MAGISKBOOT} hexpatch system/bin/recovery 080109aae80000b4 080109aae80000b5
	${MAGISKBOOT} hexpatch system/bin/recovery 20f0a6ef38b1681c 20f0a6ef38b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery 23f03aed38b1681c 23f03aed38b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery 20f09eef38b1681c 20f09eef38b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery 26f0ceec30b1681c 26f0ceec30b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery 24f0fcee30b1681c 24f0fcee30b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery 27f02eeb30b1681c 27f02eeb30b9681c
	${MAGISKBOOT} hexpatch system/bin/recovery b4f082ee28b1701c b4f082ee28b970c1
	${MAGISKBOOT} hexpatch system/bin/recovery 9ef0f4ec28b1701c 9ef0f4ec28b9701c

    cd "${WDIR}/"
}
