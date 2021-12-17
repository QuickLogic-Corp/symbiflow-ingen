#!/bin/bash

#TODO
# add logging so that intallation log is generated into the INSTALL_DIR
# add spinner and send the stuff into log file rather than everything on the console.
# add more checks and balances on each step.

# save the current directory into a variable (TMP directory)
CURRENT_DIR=$(pwd)
echo
echo "current directory is:" "$CURRENT_DIR"
echo

# conda helper functions
source "${CURRENT_DIR}/conda_helper.sh"


COLOR_BLUE="\e[1;34m"
COLOR_RED="\e[1;31m"
COLOR_GREEN="\e[1;32m"
COLOR_RESET="\e[0m"

# bash variables
TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


# banner
echo
echo -e "${COLOR_BLUE}Symbiflow Package Installer${COLOR_RESET}"
echo -e "${COLOR_BLUE}QuickLogic Corporation${COLOR_RESET}"
echo
echo

if [ -z "${INSTALL_DIR}" ]
then
    echo -e "${COLOR_RED}\$INSTALL_DIR is not set, please set and then proceed! ${COLOR_RESET}"
    echo -e "${COLOR_RED}  Example: \"export INSTALL_DIR=/<custom_location>\" ${COLOR_RESET}"
    exit 1
elif [ -d "${INSTALL_DIR}/conda" ]; then
    echo -e "${COLOR_RED}${INSTALL_DIR}/conda already exists, please clean up and re-install ! ${COLOR_RESET}"
    exit 1
else
    echo -e "${COLOR_GREEN}\$INSTALL_DIR is set to ${INSTALL_DIR} ! ${COLOR_RESET}"
fi


SYMBIFLOW_CONDA_INSTALL_DIR="${INSTALL_DIR}/conda"
SYMBIFLOW_CONDA_INIT_SCRIPT="${INSTALL_DIR}/setup.sh"

SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX="${SYMBIFLOW_CONDA_INSTALL_DIR}/envs/quicklogic"
SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_YAML="${INSTALL_DIR}/environment.yml"
SYMBIFLOW_CONDA_ENV__QUICKLOGIC__REQ_TXT="${INSTALL_DIR}/requirements.txt"
SYMBIFLOW_PACKAGE_UPDATES_YAML="${INSTALL_DIR}/package_updates.yml"

# create install directory
mkdir -p "$INSTALL_DIR"

# copy required files into INSTALL_DIR
cp -v "environment.yml" "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_YAML"
cp -v "requirements.txt" "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__REQ_TXT"

# copy the package yml file into INSTALL_DIR
cp -v "package_updates.yml" "$SYMBIFLOW_PACKAGE_UPDATES_YAML"

# navigate to the INSTALL_DIR
cd "$INSTALL_DIR"

# setup new conda env
echo
echo "creating new conda installation at: $SYMBIFLOW_CONDA_INSTALL_DIR"
echo
echo "=========================================================================================="
setup_local_conda_install $SYMBIFLOW_CONDA_INSTALL_DIR
echo "=========================================================================================="

# create the quicklogic conda environment
echo
echo "creating new conda environment at: $SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX"
echo
echo "=========================================================================================="
create_local_conda_env "$SYMBIFLOW_CONDA_INSTALL_DIR" "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX" "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_YAML"
echo "=========================================================================================="

# test the quicklogic conda env to check if it looks good
echo
echo "testing the conda environment at: $SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX"
echo
echo "=========================================================================================="
test_local_conda_env "$SYMBIFLOW_CONDA_INSTALL_DIR" "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX"
echo "=========================================================================================="

# activate the quicklogic conda env
conda activate "$SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX"
echo
echo "conda env activated:"
echo "  $SYMBIFLOW_CONDA_ENV__QUICKLOGIC__ENV_PREFIX"
echo

# !!INGEN TEMPLATE PLACEHOLDER!!


# deactivate the conda env now.
conda deactivate


# create init script for setting up conda env for symbiflow package usage

CMD_STRING_LIST=()
CMD_STRING_LIST+=("export INSTALL_DIR=$INSTALL_DIR")
CMD_STRING_LIST+=("export PATH=\"\$INSTALL_DIR/quicklogic-arch-defs/bin:\$PATH\"")
CMD_STRING_LIST+=("export PATH=\"\$INSTALL_DIR/quicklogic-arch-defs/bin/python:\$PATH\"")
CMD_STRING_LIST+=("source \"\$INSTALL_DIR/conda/etc/profile.d/conda.sh\"")
CMD_STRING_LIST+=("conda activate \${INSTALL_DIR}/conda/envs/quicklogic")
CMD_STRING_LIST+=("echo \"Quicklogic Symbiflow Package Env Activated\"")

echo "# Quicklogic Symbiflow Package Env Init Script" > "$SYMBIFLOW_CONDA_INIT_SCRIPT"

for i in "${CMD_STRING_LIST[@]}"
do
   echo "$i" >> "$SYMBIFLOW_CONDA_INIT_SCRIPT"
done

# chmod u=rwx,go=rx $SYMBIFLOW_CONDA_INIT_SCRIPT
chmod 755 "$SYMBIFLOW_CONDA_INIT_SCRIPT"


echo
echo "Remember to source the setup.sh script from the installation directory before use:"
echo "  source $SYMBIFLOW_CONDA_INIT_SCRIPT"
echo
echo -e "${COLOR_GREEN}Quicklogic Symbiflow Package Installation Complete! ${COLOR_RESET}"
echo
# done.
