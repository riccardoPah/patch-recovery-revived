#!/bin/bash

####################################
# Copyright (c) [2025] [@ravindu644]
####################################

set -e

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export WDIR="${SCRIPT_DIR}"
export RECOVERY_LINK="$1"
export MODEL="$2"
mkdir -p "recovery" "unpacked" "output"
source "${WDIR}/binaries/colors"
source "${WDIR}/binaries/gofile.sh"

# Source the hex patches database
if [ -f "${WDIR}/hex-patches.sh" ]; then
    source "${WDIR}/hex-patches.sh"
    echo -e "${LIGHT_GREEN}[INFO] Loaded $(get_patch_count) hex patches from database${RESET}\n"
else
    echo -e "${BOLD}${RED}[ERROR] hex-patches.sh not found! Please ensure it exists in the script directory.${RESET}\n"
    exit 1
fi

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
            sudo apt install -y lz4 git device-tree-compiler lz4 xz-utils zlib1g-dev openjdk-17-jdk gcc g++ python3 python-is-python3 p7zip-full android-sdk-libsparse-utils erofs-utils
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

    echo -e "\n${LIGHT_YELLOW}[INFO] Extracting:${RESET} ${BOLD}${RECOVERY_FILE}${RESET}\n"

	${MAGISKBOOT} unpack ${RECOVERY_FILE}
	${MAGISKBOOT} cpio ramdisk.cpio extract
    cd "${WDIR}/"

    echo ""    
}

# Function to apply hex patches to the recovery binary
apply_hex_patches(){
    local binary_file="$1"
    local patches_applied=0
    local total_patches=${#HEX_PATCHES[@]}
    
    echo -e "${LIGHT_YELLOW}[INFO] Applying hex patches to:${RESET} ${BOLD}${binary_file}${RESET}"
    echo -e "${LIGHT_YELLOW}[INFO] Total patches to try:${RESET} ${BOLD}${total_patches}${RESET}\n"
    
    # Temporarily disable exit on error for individual patch attempts
    set +e
    
    for patch in "${HEX_PATCHES[@]}"; do
        # Split the patch string into search and replace patterns
        local search_pattern="${patch%%:*}"
        local replace_pattern="${patch##*:}"
        
        echo -e "${LIGHT_BLUE}[PATCH] Trying:${RESET} ${search_pattern} -> ${replace_pattern}"
        
        # Apply the patch and capture the exit code
        ${MAGISKBOOT} hexpatch "${binary_file}" "${search_pattern}" "${replace_pattern}"
        local patch_result=$?
        
        if [ $patch_result -eq 0 ]; then
            echo -e "${LIGHT_GREEN}[SUCCESS] Patch applied successfully${RESET}\n"
            ((patches_applied++))
        else
            echo -e "${LIGHT_RED}[SKIP] Pattern not found, skipping${RESET}\n"
        fi
    done
    
    # Re-enable exit on error
    set -e
    
    echo -e "${LIGHT_YELLOW}[SUMMARY] Applied ${patches_applied}/${total_patches} patches${RESET}\n"
    
    # Return success if at least one patch was applied
    if [ $patches_applied -gt 0 ]; then
        echo -e "${LIGHT_GREEN}[INFO] Hex patching completed successfully${RESET}\n"
        return 0
    else
        echo -e "${BOLD}${RED}[ERROR] No matching hex byte pattern found, aborting...${RESET}\n"
        return 1
    fi
}

# Hex patch the "recovery" binary to get fastbootd mode back
hexpatch_recovery_image(){
    cd "${WDIR}/unpacked/"
    
    local recovery_binary="system/bin/recovery"
    
    if [ ! -f "${recovery_binary}" ]; then
        echo -e "${BOLD}${RED}[ERROR] Recovery binary not found: ${recovery_binary}${RESET}\n"
        exit 1
    fi
    
    # Apply hex patches and check result
    if ! apply_hex_patches "${recovery_binary}"; then
        echo -e "${BOLD}${RED}[FATAL] Hex patching failed, cannot continue${RESET}\n"
        exit 1
    fi
    
    cd "${WDIR}/"
}

# Repack the fastbootd patched recovery image
repack_recovery_image(){

    cd "${WDIR}/unpacked/"
    
    ${MAGISKBOOT}  cpio ramdisk.cpio 'add 0755 system/bin/recovery system/bin/recovery'

    echo -e "\n${LIGHT_YELLOW}[INFO] Repacking to:${RESET} ${BOLD}${WDIR}/output/patched-recovery.img${RESET}\n"

	${MAGISKBOOT}  repack ${RECOVERY_FILE} "${WDIR}/output/patched-recovery.img"

    cd "${WDIR}/"
}

# Sign the patched-recovery.img with Google's RSA private test key
sign_recovery_image(){
    echo -e "\n${LIGHT_YELLOW}[INFO] Signing with Google's RSA private test key:${RESET} ${BOLD}${WDIR}/output/patched-recovery.img${RESET}\n"

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
