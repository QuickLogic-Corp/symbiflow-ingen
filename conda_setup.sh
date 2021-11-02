#!/bin/bash

# this file is meant to be sourced and used in a script
# which wants to setup/test a new conda env at a specific location!

if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This is meant to be sourced from another script. Do not execute."
    exit 1
fi


# define this in the script that uses this script before running!
#CONDA_SETUP_BASE_INSTALL_DIR=
# this is the directory in which a "conda" directory will be created
# to hold the conda installation
if [ -z "$CONDA_SETUP_BASE_INSTALL_DIR" ] ; then

    echo
    echo "[ERROR] CONDA_SETUP_BASE_INSTALL_DIR is not defined!"
    echo
    echo "CONDA_SETUP_BASE_INSTALL_DIR needs to be defined before using this script!"
    echo

    # indicate error
    return 1

fi


# bash variables
TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


MINICONDA_INSTALLER="Miniconda3-py37_4.10.3-Linux-x86_64.sh"
MINICONDA_BASE_URL="https://repo.anaconda.com/miniconda"


# callers executing test_conda_env can use this variable to check status.
CONDA_SETUP_INSTALL_OK="$FALSE_VAL"


function setup_conda_env_paths() {

    source $CONDA_SETUP_BASE_INSTALL_DIR/conda/etc/profile.d/conda.sh

    # indicate ok
    return 0
}


# TODO, we use the base env here, we should be creating a new env from scratch?
function setup_new_conda_env() {

    # get the conda installer
    echo
    echo "downloading miniconda installer ..."
    wget -q "$MINICONDA_BASE_URL/$MINICONDA_INSTALLER" -O "$CONDA_SETUP_BASE_INSTALL_DIR/$MINICONDA_INSTALLER"
    echo "done"
    echo

    # install the conda environment into the local_dir/conda
    # -b: batch mode/no PATH modifications, -p: use prefix for conda install
    # https://docs.anaconda.com/anaconda/install/silent-mode/
    chmod +x "$CONDA_SETUP_BASE_INSTALL_DIR/$MINICONDA_INSTALLER"
    bash "$CONDA_SETUP_BASE_INSTALL_DIR/$MINICONDA_INSTALLER" -q -b -p "$CONDA_SETUP_BASE_INSTALL_DIR/conda"

    # setup the conda environment paths
    setup_conda_env_paths

    # setup custom configuration to prevent pip installing stuff into global python installation
    # https://stackoverflow.com/questions/51525072/global-pip-referenced-within-a-conda-environment
    echo 'include-system-site-packages=false' >> $CONDA_SETUP_BASE_INSTALL_DIR/conda/pyvenv.cfg

    # setup conda configuration to only use defaults/conda-forge channels and update
    conda update -y --override-channels -c defaults -c conda-forge -q conda

    # don't auto activate - not needed as local only conda install!
    #conda config --set auto_activate_base false

    echo "conda env setup complete."

    # indicate ok
    return 0
}


function test_conda_env() {

    CONDA_SETUP_INSTALL_OK="$FALSE_VAL"

    # activate the conda environment
    conda activate

    # verify the conda environment
    CONDA_PATH=$(which conda)
    CONDA_VERSION=$(conda --version)
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    PIP_PATH=$(which pip)
    PIP_VERSION=$(pip --version)

    EXPECTED_CONDA_PATH="$CONDA_SETUP_BASE_INSTALL_DIR/conda/bin/conda"
    EXPECTED_PYTHON_PATH="$CONDA_SETUP_BASE_INSTALL_DIR/conda/bin/python"
    EXPECTED_PIP_PATH="$CONDA_SETUP_BASE_INSTALL_DIR/conda/bin/pip"

    if [ "$CONDA_PATH" == "$EXPECTED_CONDA_PATH" ] &&
        [ "$PYTHON_PATH" == "$EXPECTED_PYTHON_PATH" ] &&
        [ "$PIP_PATH" == "$EXPECTED_PIP_PATH" ] ; then

        echo
        echo "$CONDA_VERSION"
        echo "$PYTHON_VERSION"
        echo "$PIP_VERSION"
        echo

        CONDA_SETUP_INSTALL_OK="$TRUE_VAL"

        echo
        echo "conda setup looks ok"
        echo

    else

        echo "conda setup is incorrect, check the script flow!"

        echo
        echo "conda"
        echo "got:     " "$CONDA_PATH"
        echo "expected:" "$EXPECTED_CONDA_PATH"
        echo
        echo "python"
        echo "got:     " "$PYTHON_PATH"
        echo "expected:" "$EXPECTED_PYTHON_PATH"
        echo
        echo "pip"
        echo "got:     " "$PIP_PATH"
        echo "expected:" "$EXPECTED_PIP_PATH"
        echo
        
    fi

    # deactivate the conda environment
    conda deactivate

    if [ ! "$CONDA_SETUP_INSTALL_OK" ==  "$TRUE_VAL" ] ; then

        # indicate error
        return 1

    fi

    # indicate ok.
    return 0
}

# indicate everything is ok when sourced!
return 0