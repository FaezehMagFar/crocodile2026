# CROCODILEworkspace

A template repository for regional ocean modeling workflows using tools developed in the NSF-funded [CROCODILE](https://github.com/CROCODILE-CESM?view_as=public) project.

In short: create your own repository from this template, run `./install.sh --workshop` to clone the CROCODILE packages, build their conda environments and render the tutorial notebooks into `workspace/`, then work from there.

**Contents**

- [Usage](#usage): using this repository as a template
- [Installation](#installation): running the installer
  - [Available Flags](#available-flags): package selection and installation options
  - [DART](#dart): pointing model2obs at a DART build
  - [Examples](#examples): common install commands
- [Subpackages](#subpackages): what each package is for
- [Workspace](#workspace): the `workspace/` folder and the rendered notebooks
- [Package versions](#package-versions): the versions installed by default, and how to pick others
  - [Updates](#updates): re-rendering the notebooks and updating packages or their environments

## Usage

This repository is a GitHub template. Click **Use this template** to create your own repository (e.g., `MyRegionalCase`), then run the installation script to set up the packages, and you can commit and track your work. CROCODILEworkspace itself remains lightweight by not committing the installed packages (they are cloned and gitignored); each run records the exact commit of every installed package in `install.d/installed_<timestamp>.txt`.

## Installation

> **Note:** for the time being, CROCODILEworkspace installation works out of the box on NCAR infrastructure (Derecho, Casper) only. We expect minimal adjustments to be required to port it to other machines and we are happy to assist you.

Requires `conda` >= 23.10 and `mamba`. On Derecho and Casper the installer runs `module load conda/latest` for you.

From the repository root, run:

```bash
./install.sh [flags]
```

### Available Flags

#### Package Selection
- `--crocodash`: Install CrocoDash model components
- `--crocogallery`: Install the CrocoGallery checkout the notebooks are rendered from
- `--model2obs`: Install model2obs diagnostics tools
- `--mom6-tools`: Install mom6-tools diagnostics tools
- `--cupid`: Install CUPiD diagnostics framework
- `--cesm`: Install CESM model
- `--cesm_da`: Install CESM_DA, a DART-enabled version of CESM. Combined with `--notebooks`, also builds a `CESM_DA` conda environment (from CrocoDash's `environment.yml` plus `pydartdiags` and `dartobsgen`, which implies `--crocodash`) for the DART notebooks in CrocoGallery
- `--dart`: Root path of an existing DART installation, used by model2obs (see [DART](#dart) below)
- `--all`: Install all packages (includes `--notebooks`)
- `--workshop`: Install all and only the packages used during the CROCODILE workshop (includes `--notebooks`)
- `--notebooks`: Render the CrocoGallery notebooks listed in `install.d/notebooks.txt` into `workspace/` (implies `--crocogallery`). Uses the CrocoDash conda env, so install `--crocodash` in the same run or an earlier one. To re-render the notebooks from the latest CrocoGallery, run `./install.sh --notebooks -f`: it re-clones CrocoGallery only, without touching CrocoDash or its env. Existing notebooks in `workspace/` are never overwritten (see [Workspace](#workspace))

#### Installation Options
- `-d, --default`: Use default paths for all packages (default behaviour, non-interactive)
- `-p, --paths`: Prompt for each package path (interactive; mutually exclusive with `-d`)
- `-f, --force`: Remove and reinstall selected packages, and overwrite their conda environments, if they already exist
- `--envs-only`: Only build the conda environments of the selected packages, without touching their checkouts or the notebooks in `workspace/`; combine with `-f` to remove and rebuild environments that already exist
- `-s, --ssh-github`: Use SSH URLs instead of HTTPS for GitHub clones (requires SSH key setup)
- `-e, --envname`: Specify prefix for conda environment names (default: no prefix, e.g. the CrocoDash environment is named `CrocoDash`; with `--envname croc` it becomes `croc-CrocoDash`)
- `-h, --help`: Display usage information and exit

You can combine multiple flags. Default paths are used unless you pass `-p`/`--paths`, which prompts for each package path and requires an interactive terminal.

If a package already exists at the target path, the script stops with an error before installing anything. Use the `-f` or `--force` flag to remove and reinstall existing packages.

Likewise, the script stops with an error also if any of the conda environments the selected packages need already exists. Use `-f`/`--force` to overwrite the existing environments, or `-e`/`--envname` to pick a different prefix.

To build only the conda environments of packages you have already downloaded, use `--envs-only`: the environments are built from the existing checkouts, and nothing is re-cloned, cleaned, or re-rendered. As in a normal install, it stops if any of the environments already exists; add `-f` to remove and rebuild them (the checkouts are still left untouched), or use `-e`/`--envname` to build them under a different prefix. With `--cesm_da` it rebuilds the `CESM_DA` environment (from the CrocoDash checkout) even without `--notebooks`; CESM has no environment. model2obs's tutorial data is not copied again.

### DART

DART is **not** installed by CROCODILEworkspace. It is an external dependency that model2obs is pointed at: model2obs runs DART's `perfect_model_obs` executable and imports DART's CrocoLake observation converter. DART has to be compiled separately; on NCAR infrastructure pre-compiled builds are available and are automatically set up with the `--workshop` flag.

The installer resolves the DART root in this order:

1. `--dart /path/to/DART`
2. the interactive prompt shown by `-p`/`--paths`
3. `DART_ROOT_PATH` exported in your environment before running `./install.sh`
4. the pre-compiled default in `install.d/generate_envpaths.sh`

### Examples

```bash
# Install packages for CROCODILE workshop with default paths
./install.sh --workshop

# Install CrocoDash and model2obs with default paths
./install.sh --crocodash --model2obs

# Install all packages with default paths
./install.sh --all

# Install all packages with default paths and custom environment prefix
./install.sh --all --envname myCroc

# Reinstall CESM (force reinstall if already exists)
./install.sh --cesm -f

# Rebuild only the CrocoDash and mom6-tools conda environments
./install.sh --crocodash --mom6-tools --envs-only -f

# Install using SSH URLs (requires GitHub SSH key)
./install.sh --crocodash --cupid -s

# Choose each package path interactively
./install.sh --all --paths

# Install model2obs against your own DART build
./install.sh --model2obs --dart /glade/work/me/DART
```

## Subpackages

- **CrocoDash**: CESM-MOM6 regional cases set up management
- **CrocoGallery**: CrocoDash tutorial and demo notebooks, rendered into `workspace/` by `--notebooks`
- **model2obs**: Diagnostics and analysis tools for MOM6 (and soon ROMS) model output
- **mom6-tools**: NCAR's diagnostics and analysis package for MOM6 model output
- **CUPiD**: NCAR's unified framework for running analysis and diagnostics on climate model output
- **CESM**: Community Earth System Model for climate simulations
- **DART**: path to DART (Data Assimilation Research Testbed), used by model2obs not installed here
- **CESM_DA**: DART-enabled Community Earth System Model

## Workspace

The installer creates a `workspace/` folder at the repository root. Some packages copy their tutorial notebooks there.

With `--notebooks` (included in `--all` and `--workshop`), the installer also renders the CrocoGallery notebooks listed in `install.d/notebooks.txt` into `workspace/`, one notebook ID per line, each saved as `workspace/<ID>.ipynb`. If `workspace/<ID>.ipynb` already exists, it is left untouched and the new render is saved as `workspace/<ID>_COPY1.ipynb` (or `_COPY2`, `_COPY3`, ... if those exist too); the same applies to the notebooks copied by `--mom6-tools`. A notebook's ID is its path inside `CrocoGallery/`, with `/` replaced by `.` and without `.ipynb` (e.g. `crocodash/tutorial-ocn.ipynb` is `crocodash.tutorial-ocn`).

The notebooks are filled in with the case directory and input directory to use (`croc_cases/` and `croc_input/`, at the CROCODILEworkspace root next to `CESM/`). To put them somewhere else, export `CASES_PATH` or `INPUT_PATH` before running the installer.

On GLADE, the notebooks are also filled in with the paths to the shared datasets (GEBCO, TPXO, ...) and with the workshop job settings (the `tutorial` queue, project `UCGD0009` and the walltimes).

## Package versions

By default, the installer checks out the versions in the table below, which were tested together. To install a different tag, branch or commit, export the matching variable, e.g. `CESM_REF=full_regional_cesm ./install.sh --cesm` to get the newest CESM on that branch.

The commit of every package installed is recorded in `install.d/installed_<timestamp>.txt`.

| Package | Variable | Default |
|---|---|---|
| CrocoDash | `CROCODASH_REF` | tag `v1.0.0` |
| CrocoGallery | `CROCOGALLERY_REF` | `main` (the notebooks rendered into `workspace/`) |
| model2obs | `MODEL2OBS_REF` | commit `317af36` on `main` |
| mom6-tools | `MOM6TOOLS_REF` | commit `8f07f2c` on `CROCODILE_workshop_2026` |
| CESM | `CESM_REF` | branch `workshop_2026` |
| CESM_DA | `CESM_DA_REF` | commit `fa0f040` on `full_regional_cesm_dart` |
| CUPiD | (fixed) | `v0.3.1` |

### Updates

#### Notebooks

To re-render the notebooks from the latest CrocoGallery, run:

```bash
./install.sh --notebooks -f
```

This re-clones CrocoGallery only, without touching CrocoDash or its env. Notebooks already in `workspace/` are not overwritten: each new render is saved as `<ID>_COPY1.ipynb` (or the next free `_COPYn`). The install record lists which file each notebook was rendered to.

#### Packages

To update an installed package, there are two options:

1. Force-reinstall it:  `./install.sh --<packagename`, e.g. `./install.sh CESM`; **This deletes the current checkout and its conda environment, if it has one,** and reinstalls the package from scratch. If you force-reinstall but would like to check out a specific tag/branch/commit see [Package versions](#package-versions).

2. Skip the delete step and update the existing checkout in place with git. For model2obs, mom6-tools and CrocoGallery, from the CROCODILEworkspace root:

    ```bash
    cd <package>
    git checkout <branch>
    git pull
    ```

    where `<package>` and `<branch>` are `model2obs` and `main`, or `mom6-tools` and `CROCODILE_workshop_2026`. (For CrocoGallery, see [Notebooks](#notebooks) above.)

    Some packages need an extra step:

    ```bash
    cd CrocoDash
    git checkout main
    git pull
    git submodule update --init --recursive
    ```

    ```bash
    cd CESM
    git checkout full_regional_cesm
    git pull
    ./bin/git-fleximod update
    ```

    ``` bash
    cd CESM_DA
    git checkout full_regional_cesm_dart
    git pull
    ./bin/git-fleximod update
    ```

    To use a different branch, tag or commit, check it out instead of the branch above.

CrocoDash, model2obs and mom6-tools are installed in their conda environments in editable mode, so code changes pulled with git are picked up without reinstalling. If an update changes the package's `environment.yml`, rebuild its environment from the updated checkout, without re-cloning it:

```bash
./install.sh --crocodash --envs-only -f
```

