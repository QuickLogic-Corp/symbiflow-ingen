#!/bin/bash



echo -e "\e[1;34mInstallation starting for conda based symbiflow\e[0m"
echo -e "\e[1;34mQuickLogic Corporation\e[0m"

if [ -z "$INSTALL_DIR" ]
then
	echo -e "\e[1;31m\$INSTALL_DIR is not set, please set and then proceed!\e[0m"
	echo -e "\e[1;31mExample: \"export INSTALL_DIR=/<custom_location>\". \e[0m"
	exit 0
elif [ -d "$INSTALL_DIR/conda" ]; then
	echo -e "\e[1;32m $INSTALL_DIR/conda already exists, please clean up and re-install ! \e[0m"
	exit 0
else
	echo -e "\e[1;32m\$INSTALL_DIR is set to $INSTALL_DIR ! \e[0m"
fi


# create install directory
mkdir -p $INSTALL_DIR


# save the current directory into a variable (TMP directory)
CURRENT_DIR=$(pwd)
echo "current directory is:" "$CURRENT_DIR"


# bash variables
TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


MINICONDA_INSTALLER="Miniconda3-py37_4.10.3-Linux-x86_64.sh"
MINICONDA_BASE_URL="https://repo.anaconda.com/miniconda"


# callers executing test_conda_env can use this variable to check status.
CONDA_SETUP_INSTALL_OK="$FALSE_VAL"


function setup_conda_env_paths() {

    source $INSTALL_DIR/conda/etc/profile.d/conda.sh

    # indicate ok
    return 0
}


# TODO, we use the base env here, we should be creating a new env from scratch?
function setup_new_conda_env() {

    # get the conda installer
    echo
    echo "downloading miniconda installer ..."
    wget -q "$MINICONDA_BASE_URL/$MINICONDA_INSTALLER" -O "$INSTALL_DIR/$MINICONDA_INSTALLER"
    echo "done"
    echo

    # install the conda environment into the local_dir/conda
    # -b: batch mode/no PATH modifications, -p: use prefix for conda install
    # https://docs.anaconda.com/anaconda/install/silent-mode/
    chmod +x "$INSTALL_DIR/$MINICONDA_INSTALLER"
    bash "$INSTALL_DIR/$MINICONDA_INSTALLER" -q -b -p "$INSTALL_DIR/conda"

    # setup the conda environment paths
    setup_conda_env_paths

    # setup custom configuration to prevent pip installing stuff into global python installation
    # https://stackoverflow.com/questions/51525072/global-pip-referenced-within-a-conda-environment
    echo 'include-system-site-packages=false' >> $INSTALL_DIR/conda/pyvenv.cfg

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

    EXPECTED_CONDA_PATH="$INSTALL_DIR/conda/bin/conda"
    EXPECTED_PYTHON_PATH="$INSTALL_DIR/conda/bin/python"
    EXPECTED_PIP_PATH="$INSTALL_DIR/conda/bin/pip"

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


# setup new conda env
setup_new_conda_env


# test the conda env to check if it looks good
test_conda_env


conda activate
echo
echo "conda env activated"
echo


conda install -y --override-channels -c defaults -c conda-forge -c litex-hub/label/main yosys="0.9_5674_gdcb7096b"
conda install -y --override-channels -c defaults -c conda-forge -c litex-hub/label/main yosys-symbiflow-plugins="1.0.0_7_413_gae520b9"
conda install -y --override-channels -c defaults -c conda-forge -c litex-hub/label/main vtr-optimized="8.0.0_4118_g06317d042"
conda install -y --override-channels -c defaults -c conda-forge -c conda-forge iverilog="10.2"
conda install -y --override-channels -c defaults -c conda-forge -c tfors gtkwave="3.3.108"
conda install -y --override-channels -c defaults -c conda-forge -c defaults make
conda install -y --override-channels -c defaults -c conda-forge -c defaults lxml
conda install -y --override-channels -c defaults -c conda-forge -c defaults simplejson
conda install -y --override-channels -c defaults -c conda-forge -c defaults intervaltree
conda install -y --override-channels -c defaults -c conda-forge -c defaults git
conda install -y --override-channels -c defaults -c conda-forge -c defaults curl
pip install python-constraint
pip install serial
echo "download and extract arch-defs tarball ..."
curl -s https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-d46f204.tar.gz --output arch.tar.gz
tar -C $INSTALL_DIR -xvf arch.tar.gz && rm arch.tar.gz
pip install git+https://github.com/QuickLogic-Corp/ql_fasm@e5d09154df9b0c6d1476ac578950ec95abb8ed86
pip install git+https://github.com/QuickLogic-Corp/quicklogic-fasm@7f6e3ab5a624674b2ccb56351d34a1852e976d62


# create setup script for setting up conda env for symbiflow package usage
SYMBIFLOW_SETUP_FILE=$INSTALL_DIR/setup.sh

echo "export INSTALL_DIR=$INSTALL_DIR" > $SYMBIFLOW_SETUP_FILE
echo "export PATH=\"\$INSTALL_DIR/quicklogic-arch-defs/bin:\$INSTALL_DIR/quicklogic-arch-defs/bin/python:\$PATH\"" >> $SYMBIFLOW_SETUP_FILE
echo "source \"\$INSTALL_DIR/conda/etc/profile.d/conda.sh\"" >> $SYMBIFLOW_SETUP_FILE
echo "conda activate" >> $SYMBIFLOW_SETUP_FILE

# chmod u=rwx,go=rx $SYMBIFLOW_SETUP_FILE
chmod 755 $SYMBIFLOW_SETUP_FILE


# run basic tests for k4n8/k6n10/eoss3/pp3 to ensure everything is ok?
# this generated installer should be going through the CI, so an end-user 
# installation test should not be required.

# deactivate the conda env now.
conda deactivate

# done.