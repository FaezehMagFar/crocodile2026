#!/usr/bin/env bash

set -euo pipefail

source ./envpaths.sh

# Set GitHub URLs based on SSH_GITHUB flag
if [[ "$SSH_GITHUB" -eq 1 ]]; then
    CROCODASH_GITHUB="git@github.com:CROCODILE-CESM/CrocoDash.git"
    CROCOGALLERY_GITHUB="git@github.com:CROCODILE-CESM/CrocoGallery.git"
    MODEL2OBS_GITHUB="git@github.com:CROCODILE-CESM/model2obs.git"
    MOM6TOOLS_GITHUB="git@github.com:NCAR/mom6-tools.git"
    CUPID_GITHUB="git@github.com:NCAR/CUPiD.git"
    CESM_GITHUB="git@github.com:CROCODILE-CESM/CESM"
    CESM_DA_GITHUB="git@github.com:CROCODILE-CESM/CESM"
else
    CROCODASH_GITHUB="https://github.com/CROCODILE-CESM/CrocoDash.git"
    CROCOGALLERY_GITHUB="https://github.com/CROCODILE-CESM/CrocoGallery.git"
    MODEL2OBS_GITHUB="https://github.com/CROCODILE-CESM/model2obs.git"
    MOM6TOOLS_GITHUB="https://github.com/NCAR/mom6-tools.git"
    CUPID_GITHUB="https://github.com/NCAR/CUPiD.git"
    CESM_GITHUB="https://github.com/CROCODILE-CESM/CESM"
    CESM_DA_GITHUB="https://github.com/CROCODILE-CESM/CESM"
fi

# Versions the workspace installs, frozen for the 2026 workshop so every
# participant gets the same code (CROCODILEworkspace#15). Export any of these
# to install a different tag, branch or commit instead (e.g. CESM_REF=main).
# CrocoDash is pinned to its v1.0.0 release, and the notebooks are rendered
# from CrocoGallery main, independent of the gallery CrocoDash pins.
CROCODASH_REF="${CROCODASH_REF:-v1.0.0}"
CROCOGALLERY_REF="${CROCOGALLERY_REF:-main}"
# Commits on model2obs main, mom6-tools CROCODILE_workshop_2026, and the CESM
# full_regional_cesm_dart branch; CESM tracks the workshop_2026 branch.
MODEL2OBS_REF="${MODEL2OBS_REF:-317af3633689e8ae01b2f5e28faaa92d4e16f1b6}"
MOM6TOOLS_REF="${MOM6TOOLS_REF:-8f07f2ce7001c477c43571fe6f1ac8c28ffd5d85}"
CESM_REF="${CESM_REF:-workshop_2026}"
CESM_DA_REF="${CESM_DA_REF:-fa0f040e525ab828e35060dc2826dd8e5653d605}"

# Check out $2 in the current repo, or exit naming package $1 and variable $3.
checkout_ref() {
    echo "Checking out $1 $2..."
    if ! git -c advice.detachedHead=false checkout "$2"; then
        echo "Error: $1 has no tag, branch or commit named '$2'." >&2
        echo "Export $3 to pick another one, e.g. $3=main ./install.sh ..." >&2
        exit 1
    fi
}

#### Existence check
# Interrrupt install if any package is already at path

EXISTING_PACKAGES=()

check_existing() {
    if [ -d "$2" ]; then
        EXISTING_PACKAGES+=("$1 at $2")
    fi
}

if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    check_existing "CrocoDash" "$CROCODASH_PATH"
fi
if [[ "$INSTALL_CROCOGALLERY" -eq 1 ]]; then
    check_existing "CrocoGallery" "$CROCOGALLERY_PATH"
fi
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    check_existing "model2obs" "$MODEL2OBS_PATH"
fi
if [[ "$INSTALL_MOM6TOOLS" -eq 1 ]]; then
    check_existing "mom6-tools" "$MOM6TOOLS_PATH"
fi
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    check_existing "CUPiD" "$CUPID_PATH"
fi
if [[ "$INSTALL_CESM" -eq 1 ]]; then
    check_existing "CESM" "$CESM_PATH"
fi
if [[ "$INSTALL_CESM_DA" -eq 1 ]]; then
    check_existing "CESM_DA" "$CESM_DA_PATH"
fi

if [[ "${#EXISTING_PACKAGES[@]}" -gt 0 ]]; then
    echo "Error: the following selected packages are already installed:" >&2
    for PKG in "${EXISTING_PACKAGES[@]}"; do
        echo "  - $PKG" >&2
    done
    echo "Use -f or --force to remove and reinstall them, or deselect them." >&2
    exit 1
fi

#### CrocoDash

if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    echo "Downloading CrocoDash..."
    git clone "$CROCODASH_GITHUB" "$CROCODASH_PATH"
    cd "$CROCODASH_PATH"
    git fetch --tags
    checkout_ref CrocoDash "$CROCODASH_REF" CROCODASH_REF
    git submodule update --init --recursive
    cd "$BASK_PATH"
    echo "CrocoDash downloaded."
fi

#### CrocoGallery

if [[ "$INSTALL_CROCOGALLERY" -eq 1 ]]; then
    echo "Downloading CrocoGallery..."
    git clone "$CROCOGALLERY_GITHUB" "$CROCOGALLERY_PATH"
    cd "$CROCOGALLERY_PATH"
    checkout_ref CrocoGallery "$CROCOGALLERY_REF" CROCOGALLERY_REF
    cd "$BASK_PATH"
    echo "CrocoGallery downloaded."
fi

#### model2obs

if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    echo "Downloading model2obs..."
    git clone "$MODEL2OBS_GITHUB" "$MODEL2OBS_PATH"
    cd "$MODEL2OBS_PATH"
    git fetch --tags
    checkout_ref model2obs "$MODEL2OBS_REF" MODEL2OBS_REF
    cd "$BASK_PATH"
    echo "model2obs downloaded."
fi

#### mom6-tools

if [[ "$INSTALL_MOM6TOOLS" -eq 1 ]]; then
    echo "Downloading mom6-tools..."
    git clone -b CROCODILE_workshop_2026 "$MOM6TOOLS_GITHUB" "$MOM6TOOLS_PATH"
    cd "$MOM6TOOLS_PATH"
    git fetch --tags
    checkout_ref mom6-tools "$MOM6TOOLS_REF" MOM6TOOLS_REF
    cd "$BASK_PATH"
    echo "mom6-tools downloaded."
fi

#### CUPiD

if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    echo "Downloading CUPiD..."
    git clone "$CUPID_GITHUB" "$CUPID_PATH"
    cd "$CUPID_PATH"
    git fetch --tags
    git checkout v0.3.1
    cd "$BASK_PATH"
    cd "$CUPID_PATH"
    git submodule update --init --recursive
    cd "$BASK_PATH"
    echo "CUPiD downloaded."
fi

#### CESM

if [[ "$INSTALL_CESM" -eq 1 ]]; then
    echo "Downloading CESM..."
    git clone -b full_regional_cesm "$CESM_GITHUB" "$CESM_PATH"
    cd "$CESM_PATH"
    checkout_ref CESM "$CESM_REF" CESM_REF
    echo "CESM downloaded."
fi

#### CESM_DA

if [[ "$INSTALL_CESM_DA" -eq 1 ]]; then
    echo "Downloading CESM_DA..."
    git clone -b full_regional_cesm_dart "$CESM_DA_GITHUB" "$CESM_DA_PATH"
    cd "$CESM_DA_PATH"
    checkout_ref CESM_DA "$CESM_DA_REF" CESM_DA_REF
    echo "CESM_DA downloaded."
fi
