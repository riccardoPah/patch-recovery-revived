#!/bin/bash

####################################
# Hex Patches Database
# Copyright (c) [2025] [@ravindu644]
####################################

# Define hex patches as an array of "search_pattern:replace_pattern" pairs
# Format: "search_hex:replace_hex"
# Each patch should be on a separate line for better readability

declare -a HEX_PATCHES=(
    "e10313aaf40300aa6ecc009420010034:e10313aaf40300aa6ecc0094"
    "eec3009420010034:eec3009420010035"
    "3ad3009420010034:3ad3009420010035"
    "50c0009420010034:50c0009420010035"
    "080109aae80000b4:080109aae80000b5"
    "20f0a6ef38b1681c:20f0a6ef38b9681c"
    "23f03aed38b1681c:23f03aed38b9681c"
    "20f09eef38b1681c:20f09eef38b9681c"
    "26f0ceec30b1681c:26f0ceec30b9681c"
    "24f0fcee30b1681c:24f0fcee30b9681c"
    "27f02eeb30b1681c:27f02eeb30b9681c"
    "b4f082ee28b1701c:b4f082ee28b970c1"
    "9ef0f4ec28b1701c:9ef0f4ec28b9701c"
    "9ef00ced28b1701c:9ef00ced28b9701c"
    "2001597ae0000054:2001597ae1000054"
    "50860494f3031f2a:5086049433008052"
    
    # One UI 7 - Galaxy A16 5G patches, Issue #4
    "9b880494e0031f2a:9b88049420008052"

    # Galaxy S24+, Issue #5
    "3f2303d5ffc301d1fd7b03a9f85f04a9f65705a9f44f06a9fdc3009129:3f2303d520008052c0035fd6f85f04a9f65705a9f44f06a9fdc3009129"
    "3f2303d5ffc301d1fd7b05a9f33300f9fd43019148:3f2303d520008052c0035fd6f33300f9fd43019148"

    # Galaxy S25, Issue #7 (func. name: GetFastbootdPermission)
    "3f2303d5ff8302d1fd7b05a9f93300f9f85f07a9f65708a9f44f09a9fd43019153:3f2303d520008052c0035fd6f93300f9f85f07a9f65708a9f44f09a9fd43019153"
    
    # Add more patches here as needed
    # Format: "search_pattern:replace_pattern"
)

# Function to get total number of patches
get_patch_count() {
    echo ${#HEX_PATCHES[@]}
}

# Function to get a specific patch by index
get_patch_by_index() {
    local index=$1
    if [[ $index -ge 0 && $index -lt ${#HEX_PATCHES[@]} ]]; then
        echo "${HEX_PATCHES[$index]}"
    else
        return 1
    fi
}

# Function to list all patches (for debugging)
list_all_patches() {
    local i=0
    for patch in "${HEX_PATCHES[@]}"; do
        echo "[$i] $patch"
        ((i++))
    done
}

export HEX_PATCHES
