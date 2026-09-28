#!/usr/bin/env bash

set -euo pipefail

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Package Selection:
  --cesm            Install CESM model
  --cesm_da         Install CESM_DA DART-enabled CESM (with --notebooks, also
                    builds a CESM_DA conda env for the DART notebooks)
  --model2obs       Install model2obs diagnostics tools
  --crocodash       Install CrocoDash model components
  --crocogallery    Install the CrocoGallery checkout the notebooks are rendered from
  --mom6-tools      Install mom6-tools diagnostics tools
  --cupid           Install CUPiD diagnostics framework
  --dart            Root of an existing DART installation (used by model2obs)
  --notebooks       Render CrocoGallery notebooks listed in install.d/notebooks.txt
                    into workspace/ in this CROCODILEworkspace folder (implies
                    --crocogallery; needs the CrocoDash env, from this or an
                    earlier install)
  --all             Install all packages (includes --notebooks)
  --workshop        Install all packages except CUPiD (includes --notebooks)

Installation Options:
  -d, --default     Use default paths for all packages (default behaviour, non-interactive)
  -p, --paths       Specify paths for all packages (interactive)
  -f, --force       Remove and reinstall selected packages (and overwrite their
                    conda environments) if they already exist
      --envs-only   Only build the conda environments of the selected packages,
                    leaving their checkouts (and notebooks) untouched; add -f to
                    remove and rebuild environments that already exist
  -s, --ssh-github  Use SSH URLs instead of HTTPS for GitHub clones (requires SSH key)
  -e, --envname     Specify prefix for conda environment names (default: none)
  -h, --help        Display this help message

Examples:
  ./install.sh --workshop
  ./install.sh --crocodash --model2obs
  ./install.sh --all --paths
  ./install.sh --cesm -d -f
  ./install.sh --crocodash --notebooks
  ./install.sh --notebooks -f      (re-render the notebooks from CrocoGallery main)
  ./install.sh --model2obs --dart /glade/work/me/DART
  ./install.sh --crocodash --mom6-tools --envs-only -f

Notes:
  - Multiple flags can be combined
  - If a package or conda environment already exists, the installer stops
    unless -f/--force is used
  - --envs-only requires the selected packages to be already downloaded; with
    --cesm_da it rebuilds the CESM_DA env (from the CrocoDash checkout), and
    CESM itself has no env
  - Edit install.d/notebooks.txt to change which gallery notebooks --notebooks renders
  - DART is not installed here: model2obs is pointed at an existing build.
    Override its location with --dart, or by exporting DART_ROOT_PATH.
EOF
}

is_ncar_hpc_host() {
    hostname_value=$(hostname -s 2>/dev/null || hostname)
    hostname_value=$(printf '%s' "$hostname_value" | tr '[:upper:]' '[:lower:]')
    case "$hostname_value" in
        dec*|derecho*|crlogin*|crht*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if is_ncar_hpc_host; then
    module load conda/latest
fi


# Check for help flag
SHOW_HELP="0"
if [ "$#" -eq 0 ]; then
    SHOW_HELP="1"
    echo "One or more packages need to be specified"
    echo ""
fi
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        SHOW_HELP="1"
    fi
done
if [[ "$SHOW_HELP" -eq 1 ]]; then
    show_help
    exit 0
fi

# generate environmental variables
INSTALL_DIR="$PWD/install.d"
cd $INSTALL_DIR
if ! ./generate_envpaths.sh "$@"; then # pass all flags
    echo ""
    show_help
    exit 1
fi

# clean already installed submodules
source ./envpaths.sh

# model2obs runs DART's perfect_model_obs and imports DART's CrocoLake
# converter, so check the DART root before building any conda environment.
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    DART_ERRORS=()
    if [[ ! -x "$DART_ROOT_PATH/models/MOM6/work/perfect_model_obs" ]]; then
        DART_ERRORS+=("not an executable: $DART_ROOT_PATH/models/MOM6/work/perfect_model_obs")
    fi
    if [[ ! -d "$DART_ROOT_PATH/observations/obs_converters/CrocoLake" ]]; then
        DART_ERRORS+=("not a directory:   $DART_ROOT_PATH/observations/obs_converters/CrocoLake")
    fi
    if [[ "${#DART_ERRORS[@]}" -gt 0 ]]; then
        echo "Error: $DART_ROOT_PATH does not look like a compiled DART installation." >&2
        for DART_ERROR in "${DART_ERRORS[@]}"; do
            echo "  - $DART_ERROR" >&2
        done
        echo "model2obs needs both of the above. Point the installer at your own build with" >&2
        echo "    ./install.sh <flags> --dart /path/to/DART" >&2
        echo "or by exporting DART_ROOT_PATH. Note that DART must be compiled for the" >&2
        echo "machine you are installing on." >&2
        exit 1
    fi
fi

# --notebooks renders with the CrocoDash env's Python. When CrocoDash isn't
# being installed in this run, reuse the env an earlier install built.
if [[ "$INSTALL_NOTEBOOKS" -eq 1 && "$INSTALL_CROCODASH" -eq 0 && "$ENVS_ONLY" -eq 0 ]]; then
    CROCODASH_ENV_NAME="${ENV_PREFIX:+${ENV_PREFIX}-}CrocoDash"
    if ! conda env list | awk '{print $1}' | grep -qx "$CROCODASH_ENV_NAME"; then
        echo "Error: --notebooks needs the CrocoDash conda env '$CROCODASH_ENV_NAME'." >&2
        echo "Install it too with: ./install.sh --crocodash --notebooks" >&2
        exit 1
    fi
fi

if [[ "$ENVS_ONLY" -eq 1 ]]; then
    # The envs are built from the existing checkouts, so they must be there;
    # CESM_DA's env is built from CrocoDash's environment.yml.
    MISSING_PACKAGES=()
    check_downloaded() {
        if [[ ! -d "$2" ]]; then
            MISSING_PACKAGES+=("$1 at $2")
        fi
    }
    [[ "$INSTALL_CROCODASH" -eq 1 || "$INSTALL_CESM_DA" -eq 1 ]] && check_downloaded "CrocoDash" "$CROCODASH_PATH"
    [[ "$INSTALL_MODEL2OBS" -eq 1 ]] && check_downloaded "model2obs" "$MODEL2OBS_PATH"
    [[ "$INSTALL_MOM6TOOLS" -eq 1 ]] && check_downloaded "mom6-tools" "$MOM6TOOLS_PATH"
    [[ "$INSTALL_CUPID" -eq 1 ]] && check_downloaded "CUPiD" "$CUPID_PATH"
    if [[ "${#MISSING_PACKAGES[@]}" -gt 0 ]]; then
        echo "Error: --envs-only needs the following packages to be already downloaded:" >&2
        for PKG in "${MISSING_PACKAGES[@]}"; do
            echo "  - $PKG" >&2
        done
        echo "Install them first by running without --envs-only." >&2
        exit 1
    fi
else
    if [[ "$FORCE" -eq 1 ]]; then
        ./clean.sh
    fi

    # download submodules
    ./init.sh
fi

# install submodules

# Source helper function
source ./setup_conda_env.sh

NBS_PATH=$BASK_PATH"/workspace/"
mkdir -p $NBS_PATH

# Echo a workspace path for <stem>.<ext> (ext defaults to ipynb) that won't
# overwrite an existing file: <stem>.<ext> if free, else <stem>_COPY1.<ext>,
# _COPY2, ...
unique_workspace_path() {
    local stem="$1" ext="${2:-ipynb}" n=1
    local path="${NBS_PATH}${stem}.${ext}"
    while [[ -e "$path" ]]; do
        path="${NBS_PATH}${stem}_COPY${n}.${ext}"
        n=$((n + 1))
    done
    echo "$path"
}
if [[ -n ${ENV_PREFIX:-} ]]; then
    ENV_PREFIX="${ENV_PREFIX}-"
fi

#### Conda environment existence check
# Resolve every env name up front (the yml-derived ones need the fresh
# clones, so this has to run after init.sh) and interrupt the install if any
# of them already exists, so that nothing gets overwritten without -f.

if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CROCODASH_PATH/environment.yml")
    CROCODASH_ENV_NAME="${ENV_PREFIX}${ENV_NAME}"
fi
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    MODEL2OBS_ENV_NAME="${ENV_PREFIX}""model2obs"
fi
if [[ "$INSTALL_MOM6TOOLS" -eq 1 ]]; then
    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$MOM6TOOLS_PATH/environment.yml")
    MOM6TOOLS_ENV_NAME="${ENV_PREFIX}${ENV_NAME}"
fi
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CUPID_PATH"/environments/cupid-infrastructure.yml)
    CUPID_ENV1_NAME="${ENV_PREFIX}${ENV_NAME}"
    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CUPID_PATH"/environments/cupid-analysis.yml)
    CUPID_ENV2_NAME="${ENV_PREFIX}${ENV_NAME}"
fi
# With --envs-only, --cesm_da is only there to select its env, so build it
# even without --notebooks.
if [[ "$INSTALL_CESM_DA" -eq 1 ]] && [[ "$INSTALL_NOTEBOOKS" -eq 1 || "$ENVS_ONLY" -eq 1 ]]; then
    CESM_DA_ENV_NAME="${ENV_PREFIX}CESM_DA"
fi

# Only the envs this run builds: CROCODASH_ENV_NAME is also set by --notebooks
# to reuse an existing env, so go by the install flags instead.
SELECTED_ENVS=()
[[ "$INSTALL_CROCODASH" -eq 1 ]] && SELECTED_ENVS+=("$CROCODASH_ENV_NAME")
[[ "$INSTALL_MODEL2OBS" -eq 1 ]] && SELECTED_ENVS+=("$MODEL2OBS_ENV_NAME")
[[ "$INSTALL_MOM6TOOLS" -eq 1 ]] && SELECTED_ENVS+=("$MOM6TOOLS_ENV_NAME")
[[ "$INSTALL_CUPID" -eq 1 ]] && SELECTED_ENVS+=("$CUPID_ENV1_NAME" "$CUPID_ENV2_NAME")
[[ -n "${CESM_DA_ENV_NAME:-}" ]] && SELECTED_ENVS+=("$CESM_DA_ENV_NAME")

if [[ "$ENVS_ONLY" -eq 1 && "${#SELECTED_ENVS[@]}" -eq 0 ]]; then
    echo "Error: none of the selected packages has a conda environment to build." >&2
    exit 1
fi

if [[ "$FORCE" -eq 1 && "$ENVS_ONLY" -eq 1 ]]; then
    for ENV_NAME in "${SELECTED_ENVS[@]}"; do
        if conda_env_exists "$ENV_NAME"; then
            echo "Removing conda environment $ENV_NAME..."
            conda env remove --name "$ENV_NAME" --yes
        fi
    done
elif [[ "$FORCE" -ne 1 ]]; then
    EXISTING_ENVS=()
    for ENV_NAME in "${SELECTED_ENVS[@]}"; do
        if conda_env_exists "$ENV_NAME"; then
            EXISTING_ENVS+=("$ENV_NAME")
        fi
    done

    if [[ "${#EXISTING_ENVS[@]}" -gt 0 ]]; then
        echo "Error: the following conda environments already exist:" >&2
        for ENV_NAME in "${EXISTING_ENVS[@]}"; do
            echo "  - $ENV_NAME" >&2
        done
        echo "Use -f or --force to overwrite them, or -e/--envname to pick a different prefix." >&2
        exit 1
    fi
fi

# CrocoDash
if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    echo "Installing CrocoDash environment..."
    cd "$CROCODASH_PATH"
    CROCODASH_SHA=$(git rev-parse HEAD)
    cd "$INSTALL_DIR"
    mamba env create -f "$CROCODASH_PATH"/environment.yml --name ${CROCODASH_ENV_NAME} --yes
    add_env_vars_to_conda "$CROCODASH_ENV_NAME"
    echo "CrocoDash environment installed."
fi

# CrocoGallery notebooks
RENDERED_NOTEBOOKS=()
if [[ "$INSTALL_NOTEBOOKS" -eq 1 && "$ENVS_ONLY" -eq 0 ]]; then
    NOTEBOOKS_LIST="$INSTALL_DIR/notebooks.txt"
    if [[ ! -f "$NOTEBOOKS_LIST" ]]; then
        echo "WARNING: --notebooks passed but $NOTEBOOKS_LIST is missing; skipping."
    else
        mkdir -p "$CASES_PATH" "$INPUT_PATH"

        # CrocoGallery's "tutorial" machine is its GLADE dataset paths (GEBCO,
        # TPXO, ...) plus the workshop batch settings: the tutorial queue, the
        # workshop project code and the walltimes. Those only resolve on
        # GLADE, so elsewhere the notebooks keep their <KEY> placeholders for
        # the user to fill in. The three paths the installer itself owns are always
        # injected, since the installer is the only thing that knows where
        # they landed.
        TEMPLATE_ARGS=()
        if [[ -d /glade/campaign/cesm/cesmdata/inputdata ]]; then
            TEMPLATE_ARGS+=(--machine tutorial)
        fi
        TEMPLATE_ARGS+=(--set "casedir=$CASES_PATH" --set "inputdir=$INPUT_PATH")
        if [[ -n "${CESM_PATH:-}" ]]; then
            TEMPLATE_ARGS+=(--set "CESM=$CESM_PATH")
        fi

        CROCOGALLERY_SHA=$(git -C "$CROCOGALLERY_PATH" rev-parse HEAD)
        echo "Rendering CrocoGallery notebooks into $NBS_PATH..."
        echo "  cases -> $CASES_PATH"
        echo "  input -> $INPUT_PATH"
        while IFS= read -r NB || [[ -n "$NB" ]]; do
            NB="${NB%%#*}"
            NB="${NB//[[:space:]]/}"
            [[ -z "$NB" ]] && continue
            OUTPUT=$(unique_workspace_path "$NB")
            if [[ "$OUTPUT" != "${NBS_PATH}${NB}.ipynb" ]]; then
                echo "  - $NB: ${NB}.ipynb already exists, keeping it"
            fi
            echo "  - $NB -> $OUTPUT"
            # Import crocogallery from the separate checkout rather than the
            # copy installed in the CrocoDash env, so the notebooks come from
            # CrocoGallery's own ref, not the gallery CrocoDash pins.
            PYTHONPATH="$CROCOGALLERY_PATH" conda run -n "$CROCODASH_ENV_NAME" \
                python -m crocogallery template \
                "${TEMPLATE_ARGS[@]}" \
                --notebook "$NB" \
                --output "$OUTPUT"
            RENDERED_NOTEBOOKS+=("$NB -> $(basename "$OUTPUT")")
        done < "$NOTEBOOKS_LIST"
        # Configs the model2obs tutorials load by name, prefixed with
        # model2obs. like the notebooks' IDs. A config that's already in the
        # workspace is kept, as for the notebooks, and the notebooks keep
        # reading it; the new one gets a _COPY suffix.
        for CONFIG in "$CROCOGALLERY_PATH"/model2obs/config_*.yaml; do
            [[ -f "$CONFIG" ]] || continue
            OUTPUT=$(unique_workspace_path "model2obs.$(basename "$CONFIG" .yaml)" yaml)
            echo "  - $(basename "$CONFIG") -> $OUTPUT"
            cp "$CONFIG" "$OUTPUT"
        done
        echo "CrocoGallery notebooks rendered."
    fi
fi

# model2obs
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    echo "Installing model2obs environment..."
    cd "$MODEL2OBS_PATH"/install
    MODEL2OBS_SHA=$(git rev-parse HEAD)
    cp envpaths_NCAR.sh envpaths.sh
    # --tutorial copies the tutorial data over whatever the tutorials wrote
    # into it, so leave it out when only rebuilding the env
    MODEL2OBS_FLAGS=()
    if [[ "$ENVS_ONLY" -eq 0 ]]; then
        MODEL2OBS_FLAGS+=(--tutorial)
    fi
    DART_ROOT_PATH=${DART_ROOT_PATH} CONDA_ENV_NAME=${MODEL2OBS_ENV_NAME} ./install_NCAR.sh "${MODEL2OBS_FLAGS[@]}"
    cd "$INSTALL_DIR"
    echo "model2obs environment installed."
fi

# The model2obs tutorials are rendered from CrocoGallery (to match the online
# gallery) but have to match the installed model2obs code: warn if they differ.
# The gallery notebooks load their configs with the workspace's model2obs.
# prefix, so drop it before comparing.
if [[ "$ENVS_ONLY" -eq 0 && -d "$MODEL2OBS_PATH/tutorials" ]]; then
    for FILE in "$CROCOGALLERY_PATH"/model2obs/{tutorial_MOM6-CL-comparison-*.ipynb,config_*.yaml}; do
        [[ -f "$FILE" ]] || continue
        sed 's/model2obs\.config_/config_/g' "$FILE" \
            | cmp -s - "$MODEL2OBS_PATH/tutorials/$(basename "$FILE")" \
            || echo "WARNING: $(basename "$FILE") differs between CrocoGallery and model2obs"
    done
fi

# mom6-tools
if [[ "$INSTALL_MOM6TOOLS" -eq 1 ]]; then
    echo "Installing mom6-tools environment..."
    cd "$MOM6TOOLS_PATH"
    MOM6TOOLS_SHA=$(git rev-parse HEAD)
    cd "$INSTALL_DIR"
    mamba env create -f "$MOM6TOOLS_PATH"/environment.yml --name ${MOM6TOOLS_ENV_NAME} --yes
    add_env_vars_to_conda "$MOM6TOOLS_ENV_NAME"
    echo "mom6-tools environment installed."

    # Notebooks are copied straight out of the checkout, same as the model2obs
    if [[ "$ENVS_ONLY" -eq 0 ]]; then
        MOM6TOOLS_NBS_DIR="mom6_tools/nb_templates/regional_notebooks"
        for NB in "$MOM6TOOLS_PATH/$MOM6TOOLS_NBS_DIR"/*.ipynb; do
            cp "$NB" "$(unique_workspace_path "mom6_tools.$(basename "$NB" .ipynb)")"
        done
    fi
fi

# CUPiD
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    echo "Installing CUPiD environments..."

    cd "$CUPID_PATH"
    CUPID_SHA=$(git rev-parse HEAD)
    cd "$INSTALL_DIR"

    mamba env create -f "$CUPID_PATH"/environments/cupid-infrastructure.yml --name ${CUPID_ENV1_NAME} --yes
    add_env_vars_to_conda "$CUPID_ENV1_NAME"

    mamba env create -f "$CUPID_PATH"/environments/cupid-analysis.yml --name ${CUPID_ENV2_NAME} --yes
    add_env_vars_to_conda "$CUPID_ENV2_NAME"

    echo "CUPiD environments installed."
fi

# CESM
if [[ "$INSTALL_CESM" -eq 1 && "$ENVS_ONLY" -eq 1 ]]; then
    echo "CESM has no conda environment; skipping."
elif [[ "$INSTALL_CESM" -eq 1 ]]; then
    echo "Installing CESM..."
    cd "$CESM_PATH"
    CESM_SHA=$(git rev-parse HEAD)
    ./bin/git-fleximod update --path "$CESM_PATH"
    cd "$INSTALL_DIR"
    echo "CESM installed."
fi

# CESM_DA
if [[ "$INSTALL_CESM_DA" -eq 1 ]]; then
    if [[ "$ENVS_ONLY" -eq 0 ]]; then
        echo "Installing CESM_DA..."
        cd "$CESM_DA_PATH"
        CESM_DA_SHA=$(git rev-parse HEAD)
        ./bin/git-fleximod update --path "$CESM_DA_PATH"
        cd "$INSTALL_DIR"
    fi

    # The CESM_DA conda env only exists to run the DART notebooks, so only
    # build it when --notebooks (or --envs-only) is requested. It's built from CrocoDash's own
    # environment.yml (its pip -e paths resolve relative to that file's
    # directory, so the generated copy has to live alongside the real
    # CrocoDash/gallery/rm6 checkouts) plus the DART notebook packages that
    # aren't part of CrocoDash itself.
    if [[ -n "${CESM_DA_ENV_NAME:-}" ]]; then
        echo "Building CESM_DA conda environment..."
        CESM_DA_ENV_FILE="$CROCODASH_PATH/cesm_da_environment.yml"
        awk '
            /^  - pip:/ { print; print "    - pydartdiags"; print "    - dartobsgen"; next }
            { print }
        ' "$CROCODASH_PATH/environment.yml" > "$CESM_DA_ENV_FILE"
        mamba env create -f "$CESM_DA_ENV_FILE" --name ${CESM_DA_ENV_NAME} --yes
        add_env_vars_to_conda "$CESM_DA_ENV_NAME"
        rm -f "$CESM_DA_ENV_FILE"
    fi

    if [[ "$ENVS_ONLY" -eq 0 ]]; then
        echo "CESM_DA installed."
    fi
fi

cat <<'EOF'
------------------------------------------------------------------------------------

   ,-----.,------.  ,-----. ,-----.  ,-----. ,------.  ,--.,--.   ,------.
  '  .--./|  .--. ''  .-.  ''  .--./'  .-.  '|  .-.  \ |  ||  |   |  .---'
  |  |    |  '--'.'|  | |  ||  |    |  | |  ||  |  \  :|  ||  |   |  `--,
  '  '--'\|  |\  \ '  '-'  ''  '--'\'  '-'  '|  '--'  /|  ||  '--.|  `---.
   `-----'`--' '--' `-----'  `-----' `-----' `-------' `--'`-----'`------'                                                                                                                                                                    
EOF
cat <<'EOF'
           ___     ___                                              ___
          /   \   /   \                                            /  /
         |   O | |   O |                                          /  /
       ,-'\___/___\___/___'-._                                   /  /
    ,-'                       ______________________            /  /
  ,'                                  ,--.   ,--.   '.         /  /
  |                    .    .         (##)   (##)    |        /  /
  '-.                                               ,'       /  /  
     _____________________________________________-'        /__/  
                 \/    \________,--------------------------.  
                                |__________________________| 

EOF
cat <<'EOF'
  ,--.   ,--. ,-----. ,------. ,--. ,--. ,---.  ,------.   ,---.   ,-----.,------.
  |  |   |  |'  .-.  '|  .--. '|  .'   /'   .-' |  .--. ' /  O  \ '  .--./|  .---'
  |  |.'.|  ||  | |  ||  '--'.'|  .   ' `.  `-. |  '--' ||  .-.  ||  |    |  `--,
  |   ,'.   |'  '-'  '|  |\  \ |  |\   \.-'    ||  | --' |  | |  |'  '--'\|  `---.
  '--'   '--' `-----' `--' '--'`--' '--'`-----' `--'     `--' `--' `-----'`------'

------------------------------------------------------------------------------------
EOF

echo ""
if [[ "$ENVS_ONLY" -eq 1 ]]; then
    echo "Conda environments built."
    echo "Components, environments and paths:"
else
    echo "Install complete."
    echo "Components, environments and paths installed:"
fi
echo ""

DATETIME=$(date "+%Y-%m-%d_%H-%M-%S")
INSTALL_RECORD="installed_${DATETIME}.txt"
touch $INSTALL_RECORD

if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CrocoDash:
    path:   $CROCODASH_PATH
    commit: $CROCODASH_SHA
    conda environment: $CROCODASH_ENV_NAME

EOF
fi
if [[ "$INSTALL_NOTEBOOKS" -eq 1 && "${#RENDERED_NOTEBOOKS[@]}" -gt 0 ]]; then
    {
        echo "CrocoGallery notebooks:"
        echo "    path:   $CROCOGALLERY_PATH"
        echo "    commit: $CROCOGALLERY_SHA"
        echo "    workspace: $NBS_PATH"
        echo "    case directory: $CASES_PATH"
        echo "    input directory: $INPUT_PATH"
        for NB in "${RENDERED_NOTEBOOKS[@]}"; do
            echo "    - $NB"
        done
    } | tee -a $INSTALL_RECORD
    echo ""
fi
if [[ "$INSTALL_CESM" -eq 1 && "$ENVS_ONLY" -eq 0 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CESM:
    path:   $CESM_PATH
    commit: $CESM_SHA

EOF
fi
if [[ "$INSTALL_CESM_DA" -eq 1 ]]; then
    {
        echo "CESM_DA:"
        if [[ "$ENVS_ONLY" -eq 0 ]]; then
            echo "    path:   $CESM_DA_PATH"
            echo "    commit: $CESM_DA_SHA"
        fi
        if [[ -n "${CESM_DA_ENV_NAME:-}" ]]; then
            echo "    conda environment: $CESM_DA_ENV_NAME"
        fi
        echo ""
    } | tee -a $INSTALL_RECORD
fi
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
MODEL2OBS:
    path:   $MODEL2OBS_PATH
    commit: $MODEL2OBS_SHA
    conda environment: $MODEL2OBS_ENV_NAME
    DART root path: $DART_ROOT_PATH

EOF
fi
if [[ "$INSTALL_MOM6TOOLS" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
mom6-tools:
    path:   $MOM6TOOLS_PATH
    commit: $MOM6TOOLS_SHA
    conda environment: $MOM6TOOLS_ENV_NAME

EOF
fi
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CUPiD:
    path:   $CUPID_PATH
    commit: $CUPID_SHA
    conda environments: $CUPID_ENV1_NAME
                        $CUPID_ENV2_NAME

EOF
fi

echo "To activate an environment:"
echo "module load conda"
echo "conda activate <environment-name>"
echo "(example: conda activate CrocoDash)"
echo ""
echo "If you specified a prefix for environment names:"
echo "conda activate <prefix>-CrocoDash"
