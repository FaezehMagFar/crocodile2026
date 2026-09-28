#!/usr/bin/env bash

# Only enable strict mode if not being sourced
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && set -euo pipefail

export BASK_PATH="$(realpath -m "$(dirname "$PWD")")"

# Array of package names and their relative default paths
declare -A PKG_PATHS=(
    [CESM]="CESM"
    [CESM_DA]="CESM_DA"
    [MODEL2OBS]="model2obs"
    [CROCODASH]="CrocoDash"
    [CROCOGALLERY]="CrocoGallery"
    [MOM6TOOLS]="mom6-tools"
    [CUPID]="CUPiD"
)

# Initialize flags to 0 and paths to empty
for PKG in "${!PKG_PATHS[@]}"; do
    declare "${PKG}=0"
    export "${PKG}_PATH="
done
DEFAULT=1
DEFAULT_FLAG=0
PATHS_FLAG=0
FORCE=0
ENVS_ONLY=0
SSH_GITHUB=0
ENV_PREFIX=''
NOTEBOOKS=0
DART_PATH_FLAG=''

# Register what packages need to be installed from CLI flags
UNKNOWN_ARGS=()
for ((i=1; i<=$#; i++)); do
    arg="${!i}"

    case "$arg" in
        --envname|-e)
            ((i++))
            if [[ "$i" -gt "$#" ]]; then
                echo "Error: $arg requires a value" >&2
                exit 1
            fi
            ENV_PREFIX="${!i}"
            ;;
        --dart)
            ((i++))
            if [[ "$i" -gt "$#" ]]; then
                echo "Error: $arg requires a value" >&2
                exit 1
            fi
            DART_PATH_FLAG="${!i}"
            ;;
        --all)
            for PKG in "${!PKG_PATHS[@]}"; do
                declare "${PKG}=1"
            done
            NOTEBOOKS=1
            ;;
        --notebooks) NOTEBOOKS=1 ;;
        --workshop)
            for PKG in "${!PKG_PATHS[@]}"; do
                if [[ "$PKG" != "CUPID" ]]; then
                    declare "${PKG}=1"
                fi
            done
            NOTEBOOKS=1
            ;;
        -d|--default) DEFAULT_FLAG=1 ;;
        -p|--paths) PATHS_FLAG=1 ;;
        -f|--force) FORCE=1 ;;
        --envs-only) ENVS_ONLY=1 ;;
        -s|--ssh-github) SSH_GITHUB=1 ;;
        *)
            upper="${arg#--}"
            upper="${upper^^}"
            upper="${upper//-/}"
            if [[ -v PKG_PATHS[$upper] ]]; then
                declare "${upper}=1"
            else
                UNKNOWN_ARGS+=("$arg")
            fi
            ;;
    esac
done

if [[ "${#UNKNOWN_ARGS[@]}" -gt 0 ]]; then
    echo "Error: unrecognized argument(s): ${UNKNOWN_ARGS[*]}" >&2
    exit 1
fi

if [[ "$DEFAULT_FLAG" -eq 1 && "$PATHS_FLAG" -eq 1 ]]; then
    echo "Error: -d/--default and -p/--paths are mutually exclusive" >&2
    exit 1
fi
if [[ "$PATHS_FLAG" -eq 1 ]]; then
    if [ ! -t 0 ]; then
        echo "Error: -p/--paths requires an interactive terminal" >&2
        exit 1
    fi
    DEFAULT=0
fi

# --notebooks renders from its own CrocoGallery checkout, using an existing
# CrocoDash env's Python, so re-rendering only re-clones the gallery. CESM_DA's
# notebook env is built from CrocoDash's environment.yml, so that combination
# still needs the CrocoDash checkout.
if [[ "$NOTEBOOKS" -eq 1 ]]; then
    CROCOGALLERY=1
    if [[ "$CESM_DA" -eq 1 ]]; then
        CROCODASH=1
    fi
fi

# Assign paths
if [[ "$DEFAULT" -eq 1 ]]; then
    for PKG in "${!PKG_PATHS[@]}"; do
        export "${PKG}_PATH"="$(realpath -m "$BASK_PATH/${PKG_PATHS[$PKG]}")"
        echo "$PKG root path set to $(eval echo \${${PKG}_PATH})"
    done
else
    for PKG in "${!PKG_PATHS[@]}"; do
        DEF="$BASK_PATH/${PKG_PATHS[$PKG]}"
        printf "Please provide %s root path (default: %s): " "$PKG" "$DEF"
        read -r input_path
        if [ -n "$input_path" ]; then
            export "${PKG}_PATH"="$(realpath -m "$input_path")"
        else
            export "${PKG}_PATH"="$(realpath -m "$DEF")"
        fi
        echo "$PKG root path set to $(eval echo \${${PKG}_PATH})"
    done
fi

# Where the rendered gallery notebooks put their CESM cases and their MOM6
# input files. These are not packages -- nothing is installed into them -- but
# the notebooks need real directories, so they are resolved here alongside the
# package paths and injected at render time. They sit in the workspace next to
# the CESM checkout, so everything a workspace makes stays in one place.
export CASES_PATH="$(realpath -m "${CASES_PATH:-$BASK_PATH/croc_cases}")"
export INPUT_PATH="$(realpath -m "${INPUT_PATH:-$BASK_PATH/croc_input}")"

# Root of the existing DART installation that model2obs is pointed at: DART is
# not installed here, and is compiled separately for each machine.
# Resolution order: --dart > prompt (-p) > inherited $DART_ROOT_PATH > default.
DEFAULT_DART_ROOT_PATH="/glade/u/home/emilanese/work/DART-11.21.2-Casper"

if [[ -n "$DART_PATH_FLAG" ]]; then
    DART_ROOT_PATH="$DART_PATH_FLAG"
else
    DART_ROOT_PATH="${DART_ROOT_PATH:-$DEFAULT_DART_ROOT_PATH}"
    if [[ "$DEFAULT" -eq 0 && "$MODEL2OBS" -eq 1 ]]; then
        printf "Please provide DART root path (default: %s): " "$DART_ROOT_PATH"
        read -r input_path
        if [ -n "$input_path" ]; then
            DART_ROOT_PATH="$input_path"
        fi
    fi
fi
export DART_ROOT_PATH="$(realpath -m -s "$DART_ROOT_PATH")"
if [[ "$MODEL2OBS" -eq 1 ]]; then
    echo "DART root path set to $DART_ROOT_PATH"
fi

# Write all paths to envpaths.sh
ENV_FILE="envpaths.sh"
: > "$ENV_FILE"  # Truncate file

echo "export BASK_PATH=\"${BASK_PATH}\"" >> "$ENV_FILE"
for PKG in "${!PKG_PATHS[@]}"; do
    # Use eval to expand the actual value of the variable
    VAL=$(eval echo "\${${PKG}_PATH}")
    echo "export ${PKG}_PATH=\"$VAL\"" >> "$ENV_FILE"
done
for PKG in "${!PKG_PATHS[@]}"; do
    # Use eval to expand the actual value of the variable
    VAL=$(eval echo "\${${PKG}}")
    echo "export INSTALL_${PKG}=\"$VAL\"" >> "$ENV_FILE"
done
echo "export FORCE=\"$FORCE\"" >> "$ENV_FILE"
echo "export ENVS_ONLY=\"$ENVS_ONLY\"" >> "$ENV_FILE"
echo "export SSH_GITHUB=\"$SSH_GITHUB\"" >> "$ENV_FILE"
echo "export ENV_PREFIX=\"$ENV_PREFIX\"" >> "$ENV_FILE"
echo "export INSTALL_NOTEBOOKS=\"$NOTEBOOKS\"" >> "$ENV_FILE"
echo "export CASES_PATH=\"$CASES_PATH\"" >> "$ENV_FILE"
echo "export INPUT_PATH=\"$INPUT_PATH\"" >> "$ENV_FILE"
echo "export DART_ROOT_PATH=\"$DART_ROOT_PATH\"" >> "$ENV_FILE"
