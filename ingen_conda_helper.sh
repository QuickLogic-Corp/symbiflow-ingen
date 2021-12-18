#!/bin/bash

# this file is meant to be sourced and used in a script
# which wants to setup/test a new conda env at a specific location!

if [[ "$0" = "$BASH_SOURCE" ]]; then
    echo "This is meant to be sourced from another script. Do not execute."
    exit 1
fi


# bash variables
TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


MINICONDA_INSTALLER="Miniconda3-py37_4.10.3-Linux-x86_64.sh"
MINICONDA_BASE_URL="https://repo.anaconda.com/miniconda"


# setup_local_conda_install_paths </path/to/conda/install/dir>
function setup_local_conda_install_paths() {

    if [ ! $# == 1 ] ; then

        echo
        echo "usage: setup_local_conda_install_paths </path/to/conda/install/dir>"
        
        return 1

    fi

    # pass in the directory where the conda installation is available
    CONDA_INSTALL_DIR=$1

    # source conda setup script so 'conda' commands are available
    # TODO  we can check if this has already been done in current shell
    #       using output of `which conda` and checking the path to be $CONDA_INSTALL_DIR/condabin/conda
    source $CONDA_INSTALL_DIR/etc/profile.d/conda.sh

    # indicate ok
    return 0
}


# setup_local_conda_install </path/to/conda/install/dir>
function setup_local_conda_install() {

    if [ ! $# == 1 ] ; then

        echo
        echo "usage: setup_local_conda_install </path/to/conda/install/dir>"
        
        return 1

    fi

    # pass in the directory where the conda should be installed
    CONDA_INSTALL_DIR=$1

    # get the conda installer
    echo
    echo "downloading miniconda installer ..."
    wget -q "$MINICONDA_BASE_URL/$MINICONDA_INSTALLER" -O "$MINICONDA_INSTALLER"
    echo "done"
    echo

    # install the conda environment into the local_dir/conda
    # -b: batch mode/no PATH modifications, -p: use prefix for conda install
    # https://docs.anaconda.com/anaconda/install/silent-mode/
    chmod +x "$MINICONDA_INSTALLER"
    bash "$MINICONDA_INSTALLER" -q -b -p "$CONDA_INSTALL_DIR"

    # setup the conda install paths
    setup_local_conda_install_paths "$CONDA_INSTALL_DIR"

    # setup custom configuration to prevent pip installing stuff into global python installation
    # https://stackoverflow.com/questions/51525072/global-pip-referenced-within-a-conda-environment
    echo 'include-system-site-packages=false' >> $CONDA_INSTALL_DIR/pyvenv.cfg

    # update conda itself
    conda update -y --override-channels -c defaults -q conda

    # disable auto activate of base environment
    # (no need as local only conda install)
    #conda config --set auto_activate_base false

    # remove the conda installer binary
    rm -f "$MINICONDA_INSTALLER"

    # indicate ok
    return 0
}


# create_local_conda_env </path/to/conda/install/dir> </path/to/environment/> </path/to/environment/yaml/>
function create_local_conda_env() {

    if [ ! $# == 3 ] ; then

        echo
        echo "usage: create_local_conda_env </path/to/conda/install/dir> </path/to/environment/> </path/to/environment/yaml/>"
        
        return 1

    fi

    CONDA_INSTALL_DIR=$1
    CONDA_ENVIRONMENT_PREFIX=$2
    CONDA_ENVIRONMENT_YAML_FILE=$3

    setup_local_conda_install_paths $CONDA_INSTALL_DIR

    conda env create -f "$CONDA_ENVIRONMENT_YAML_FILE" -p "$CONDA_ENVIRONMENT_PREFIX"
    STATUS=$?

    return $STATUS
}


# delete_local_conda_env </path/to/conda/install/dir> </path/to/environment/>
function delete_local_conda_env() {

    if [ ! $# == 2 ] ; then

        echo
        echo "usage: delete_local_conda_env </path/to/conda/install/dir> </path/to/environment/>"
        
        return 1

    fi

    CONDA_INSTALL_DIR=$1
    CONDA_ENVIRONMENT_PREFIX=$2

    setup_local_conda_install_paths $CONDA_INSTALL_DIR

    conda env remove -p "$CONDA_ENVIRONMENT_PREFIX"
    STATUS=$?

    return $STATUS
}


# test_local_conda_env </path/to/conda/install/dir> </path/to/environment/>
function test_local_conda_env() {

    if [ ! $# == 2 ] ; then

        echo
        echo "usage: test_local_conda_env </path/to/conda/install/dir> </path/to/environment/>"
        
        return 1

    fi

    # pass in the directory where the conda should be installed
    CONDA_INSTALL_DIR=$1
    CONDA_ENVIRONMENT_PREFIX=$2

    CONDA_SETUP_INSTALL_OK="$FALSE_VAL"

    # activate the conda environment
    conda activate "$CONDA_ENVIRONMENT_PREFIX"

    # verify the conda environment
    CONDA_PATH=$(which conda)
    CONDA_VERSION=$(conda --version)
    PYTHON_PATH=$(which python)
    PYTHON_VERSION=$(python --version)
    PIP_PATH=$(which pip)
    PIP_VERSION=$(pip --version)

    EXPECTED_CONDA_PATH="${CONDA_INSTALL_DIR}/condabin/conda"
    EXPECTED_PYTHON_PATH="${CONDA_ENVIRONMENT_PREFIX}/bin/python"
    EXPECTED_PIP_PATH="${CONDA_ENVIRONMENT_PREFIX}/bin/pip"

    if [ "$CONDA_PATH" == "$EXPECTED_CONDA_PATH" ] &&
        [ "$PYTHON_PATH" == "$EXPECTED_PYTHON_PATH" ] &&
        [ "$PIP_PATH" == "$EXPECTED_PIP_PATH" ] ; then

        echo
        echo "conda setup looks ok:"
        echo
        echo "$CONDA_VERSION"
        echo "$PYTHON_VERSION"
        echo "$PIP_VERSION"
        echo

        CONDA_SETUP_INSTALL_OK="$TRUE_VAL"

        
        echo

    else

        echo
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