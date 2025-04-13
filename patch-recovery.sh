#!/bin/bash

####################################
# Copyright (c) [2025] [@ravindu644]
####################################

set -e -x

export WDIR="$(pwd)"
export RECOVERY_LINK="$1"
mkdir -p "${WDIR}/recovery"

# Downloading/copying the recovery

if [[ "${RECOVERY_LINK}" =~ ^https?:// ]]; then
  curl -L "${RECOVERY_LINK}" -o "${WDIR}/recovery/$(basename "${RECOVERY_LINK}")"
elif [ -f "${RECOVERY_LINK}" ]; then
  cp "${RECOVERY_LINK}" "${WDIR}/recovery/"
else
  echo -e "Invalid input: not a URL or file.\n"
  echo -e "If you entered a URL, make sure it begins with 'http://' or 'https://'"
  exit 1
fi
