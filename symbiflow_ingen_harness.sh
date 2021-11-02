#!/bin/bash


# bash variables
TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


# define the base dir path where conda env should be installed
# for InGen, we use the current directory
CONDA_SETUP_BASE_INSTALL_DIR="$PWD"
source ./conda_setup.sh
# check if any errors in sourcing : $?
#echo $?

function install_prerequisites() {

    echo
    echo "installing dependencies..."
    echo

    # activate the conda environment
    conda activate

    # install any dependencies here
    #pip install pyyaml # replaced with raumel.yaml
    #pip install raumel.yaml # use raumel_yaml built into conda base
    conda install jq    # json parsing
    conda install ruamel_yaml # latest needed, for bug fixes

    # deactivate the conda environment
    conda deactivate

    echo
    echo "dependencies installed"
    echo
}


# development settings: do not setup fresh conda env, if it already exists!
DEVELOPMENT_MODE="dev"
DEVELOPMENT_MODE_ENABLED="$FALSE_VAL"
#echo $#
#echo $@
#echo ${0}
#echo `basename ${0}`
if [ $# == 1 ] ; then

    if [ $1 == "$DEVELOPMENT_MODE" ] ; then

        echo "DEV MODE specified!"
        DEVELOPMENT_MODE_ENABLED="$TRUE_VAL"

    fi

fi

# setup the conda environment and configure it
if [ "$DEVELOPMENT_MODE_ENABLED" == "$TRUE_VAL" ] ; then

    # check for existing conda environment
    if [ -d "$PWD/conda" ] ; then

        # already exists, nothing do further to setup a new env in development mode
        echo "[DEV MODE] reusing existing conda env in:" "$PWD/conda"

        # setup the conda environment paths
        setup_conda_env_paths


    else

        # conda env dir does not exist
        echo "[DEV MODE] conda env does not exist, create new conda env"

        # setup new conda env
        setup_new_conda_env
        # once conda env is setup, install prerequisites for ingen
        install_prerequisites

    fi

else # USER MODE, start fresh conda env always

    # check for existing conda environment
    if [ -d "$PWD/conda" ] ; then

        # clean it up
        echo "clean up existing conda env in:" "$PWD/conda"
        rm -rf "$PWD/conda"

    fi

    # setup new conda env
    setup_new_conda_env
    # once conda env is setup, install prerequisites for ingen
    install_prerequisites

fi

# test the conda env to check if it looks good
test_conda_env

# install any prerequisites needed for ingen

conda activate
echo
echo "conda env activated"
echo


# work with the conda env START

python3 symbiflow_ingen.py

# work with the conda env END

# finally deactivate
conda deactivate

echo
echo "conda env deactivated"
echo