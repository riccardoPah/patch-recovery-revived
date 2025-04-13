#!/bin/bash

####################################
# Copyright (c) [2025] [@ravindu644]
####################################

set -e

export WDIR="$(pwd)"
export RECOVERY_LINK="$1"
export MODEL="$2"
mkdir -p "recovery" "unpacked" "output"
source "${WDIR}/binaries/colors"
source "${WDIR}/binaries/gofile.sh"

# Clean-up is required
rm -rf "${WDIR}/recovery/"*
rm -rf "${WDIR}/unpacked/"*

# Define magiskboot,avbtool and signing key paths
AVB_KEY="${WDIR}/signing-keys/testkey_rsa2048.pem"
AVBTOOL="${WDIR}/binaries/avbtool"
MAGISKBOOT="${WDIR}/binaries/magiskboot"

# Define the usage
usage() {
  echo -e "${BOLD}${RED}Usage:${RESET} ${BOLD}./patch-recovery.sh <URL/Path> <Model Number>${RESET}"
  exit 1
}

[[ -z "$RECOVERY_LINK" || -z "$MODEL" ]] && usage

# Welcome banner, Install requirements if not installed
init_patch_recovery(){
    echo -e "\n${BLUE}patch-recovery-revived - By @ravindu644${RESET}\n"

    # Install the requirements for building the kernel when running the script for the first time
    if [ ! -f ".requirements" ]; then
        echo -e "\n\t${UNBOLD_GREEN}Installing requirements...${RESET}\n"
        {
            sudo apt update
            sudo apt install -y lz4
        } && touch .requirements
    fi
}

# Downloading/copying the recovery
download_recovery(){
    if [[ "${RECOVERY_LINK}" =~ ^https?:// ]]; then

    echo -e "${LIGHT_YELLOW}[INFO] Downloading:${RESET} ${BOLD}${RECOVERY_LINK}${RESET}\n"

    curl -L "${RECOVERY_LINK}" -o "${WDIR}/recovery/$(basename "${RECOVERY_LINK}")"
    elif [ -f "${RECOVERY_LINK}" ]; then
    cp "${RECOVERY_LINK}" "${WDIR}/recovery/"
    else
    echo -e "${BOLD}${RED}Invalid input: not a URL or file.${RESET}\n"
    echo -e "${BOLD}${RED}If you entered a URL, make sure it begins with 'http://' or 'https://'${RESET}\n"
    exit 1
    fi
}

# Check if the downloaded/copied file an archive
unarchive_recovery(){

    set -x 
    cd "${WDIR}/recovery/"
    local FILE=$(ls)
    [[ "$FILE" == *.zip ]] && unzip "$FILE" && rm "$FILE"
    [[ "$FILE" == *.lz4 ]] && lz4 -d "$FILE" "${FILE%.lz4}" && rm "$FILE"

    # Only rename if recovery.img doesn't exists
    if [ ! -f recovery.img ]; then
        mv "$(ls *.img)" "recovery.img"
    fi

    cd "${WDIR}/"

    export RECOVERY_FILE="${WDIR}/recovery/recovery.img"
    export RECOVERY_SIZE=$(stat -c%s "${WDIR}/recovery/recovery.img")
    set +x
}

# Extract recovery.img
extract_recovery_image(){
    cd "${WDIR}/unpacked/"

    echo -e "${LIGHT_YELLOW}[INFO] Extracting:${RESET} ${BOLD}${RECOVERY_FILE}${RESET}\n"

	${MAGISKBOOT} unpack ${RECOVERY_FILE}
	${MAGISKBOOT} cpio ramdisk.cpio extract
    cd "${WDIR}/"
}

# Hex patch the "recovery" binary to get fastbootd mode back
hexpatch_recovery_image(){
    cd "${WDIR}/unpacked/"

    echo -e "${LIGHT_YELLOW}[INFO] Hex-patching:${RESET} ${BOLD}system/bin/recovery${RESET}\n"

    set +x

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

    set -x

    cd "${WDIR}/"
}

# Repack the fastbootd patched recovery image
repack_recovery_image(){
    cd "${WDIR}/unpacked/"

    ${MAGISKBOOT}  cpio ramdisk.cpio 'add 0755 system/bin/recovery system/bin/recovery'

    echo -e "${LIGHT_YELLOW}[INFO] Repacking to:${RESET} ${BOLD}${WDIR}/output/patched-recovery.img${RESET}\n"

	${MAGISKBOOT}  repack ${RECOVERY_FILE} "${WDIR}/output/patched-recovery.img"

    cd "${WDIR}/"
}

# Sign the patched-recovery.img with Google's RSA private test key
sign_recovery_image(){

    echo -e "${LIGHT_YELLOW}[INFO] Signing with Google's RSA private test key:${RESET} ${BOLD}${WDIR}/output/patched-recovery.img${RESET}\n"

    ${AVBTOOL} \
        add_hash_footer \
        --partition_name recovery \
        --partition_size ${RECOVERY_SIZE} \
        --image "${WDIR}/output/patched-recovery.img" \
        --key ${AVB_KEY} \
        --algorithm SHA256_RSA2048
}

# Create an ODIN-flashable tar
create_tar(){
    cd "${WDIR}/output/"

    mv patched-recovery.img recovery.img && \
        lz4 -B6 --content-size recovery.img recovery.img.lz4 && \
        rm recovery.img

    tar -cvf "${MODEL}-Fastbootd-patched-recovery.tar" recovery.img.lz4 && \
        rm recovery.img.lz4

    echo -e "\n${LIGHT_YELLOW}[INFO] Created ODIN-flashable tar:${RESET} ${BOLD}${PWD}/${MODEL}-Fastbootd-patched-recovery.tar${RESET}\n"

    # Optional GoFile upload
    if [[ "$GOFILE" == "1" ]]; then
        upload_to_gofile "${MODEL}-Fastbootd-patched-recovery.tar"
    fi
    
    cd "${WDIR}/"
}

cleanup_source(){
    rm -rf "${WDIR}/recovery/"*
    rm -rf "${WDIR}/unpacked/"*    
}

init_patch_recovery
download_recovery
unarchive_recovery
extract_recovery_image
hexpatch_recovery_image
repack_recovery_image
sign_recovery_image
create_tar
cleanup_source
