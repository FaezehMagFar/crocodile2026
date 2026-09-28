#!/usr/bin/env bash

set -euo pipefail

# Function to check whether a conda environment with the given name exists
# Arguments: $1 = environment name
conda_env_exists() {
    conda env list | awk -v env="$1" '$1 == env {found=1} END {exit !found}'
}

# Function to add environment variables to conda environment
# Arguments: $1 = environment name
add_env_vars_to_conda() {
    local ENV_NAME=$1
    local CONDA_PREFIX=$(conda env list | grep "^${ENV_NAME} " | awk '{print $NF}')
    
    if [ -z "$CONDA_PREFIX" ]; then
        echo "Error: Environment $ENV_NAME not found"
        return 1
    fi
    
    local ACTIVATE_DIR="$CONDA_PREFIX/etc/conda/activate.d"
    local LOAD_SCRIPT="$ACTIVATE_DIR/load_bask_paths.sh"
    
    # Create activate.d directory if it doesn't exist
    mkdir -p "$ACTIVATE_DIR"
    
    echo "Setting up environment variables for $ENV_NAME..."
    
    # Read envpaths.sh and process each export
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Extract variable name and value from export lines
        if [[ "$line" =~ ^export[[:space:]]+([^=]+)=\"(.*)\"$ ]]; then
            VAR_NAME="${BASH_REMATCH[1]}"
            VAR_VALUE="${BASH_REMATCH[2]}"
            
            # Check if variable already exists in the script
            if [ -f "$LOAD_SCRIPT" ]; then
                if grep -q "^export ${VAR_NAME}=" "$LOAD_SCRIPT"; then
                    # Variable exists, check if value is different
                    EXISTING_VALUE=$(grep "^export ${VAR_NAME}=" "$LOAD_SCRIPT" | sed "s/^export ${VAR_NAME}=\"\(.*\)\"$/\1/")
                    if [ "$EXISTING_VALUE" != "$VAR_VALUE" ]; then
                        echo "Error: Variable $VAR_NAME already exists in $LOAD_SCRIPT with different value"
                        echo "  Existing: $EXISTING_VALUE"
                        echo "  New:      $VAR_VALUE"
                        return 1
                    fi
                    # Same value, skip
                    continue
                fi
            fi
            
            # Append the export to the script
            echo "export ${VAR_NAME}=\"${VAR_VALUE}\"" >> "$LOAD_SCRIPT"
        fi
    done < ./envpaths.sh
    
    echo "Environment variables configured for $ENV_NAME"
}

# Export the functions so they can be used by install.sh
export -f conda_env_exists
export -f add_env_vars_to_conda
