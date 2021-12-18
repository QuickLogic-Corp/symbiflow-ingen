#!/bin/bash


##########################################################################################
# EXPORTED VARIABLES: use the variables exported from parent script : ingen_kickoff.sh
##########################################################################################
INGEN_ROOT_DIR="."

# path to generate the Symbiflow Package Installer
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE="$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE"
##########################################################################################


# conda helper functions
INGEN_CONDA_HELPER_SCRIPT="${INGEN_ROOT_DIR}/ingen_conda_helper.sh"
source "$INGEN_CONDA_HELPER_SCRIPT"

TRUE_VAL="TRUE"
FALSE_VAL="FALSE"


# where should we install conda ?
INGEN_CONDA_INSTALL_DIR="${INGEN_ROOT_DIR}/conda"

INGEN_PACKAGE_SPEC_YAML="${INGEN_ROOT_DIR}/ingen_package_spec.yml"
INGEN_PACKAGE_UPDATES_YAML="${INGEN_ROOT_DIR}/ingen_package_updates.yml"
INGEN_PACKAGE_CURRENT_YAML="${INGEN_ROOT_DIR}/ingen_package_current.yml"
INGEN_INSTALLER_SCRIPT_TEMPLATE="${INGEN_ROOT_DIR}/ingen_installer_script_template.sh"

INGEN_CONDA_ENV__INGEN__ENV_PREFIX="${INGEN_CONDA_INSTALL_DIR}/envs/ingen"
INGEN_CONDA_ENV__INGEN__ENV_YAML="ingen_environment.yml"
INGEN_CONDA_ENV__INGEN__REQ_TXT="ingen_requirements.txt" # we don't directly use, it is in the yml

INGEN_BUILDER_DATA_DIR="${INGEN_ROOT_DIR}/builder_data"
INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX="${INGEN_CONDA_INSTALL_DIR}/envs/ingen_builder"
INGEN_CONDA_ENV__INGEN_BUILDER__ENV_YAML="${INGEN_BUILDER_DATA_DIR}/environment.yml"
INGEN_CONDA_ENV__INGEN_BUILDER__REQ_TXT="${INGEN_BUILDER_DATA_DIR}/requirements.txt" # we don't directly use, it is in the yml
INGEN_BUILDER_DATA_CONDA_PACKAGES_JSON="$INGEN_BUILDER_DATA_DIR/conda_list.json"
INGEN_BUILDER_DATA_PIP_PACKAGES_JSON="$INGEN_BUILDER_DATA_DIR/pip_list.json"

INGEN_SYMBIFLOW_INSTALLER_DIR="${INGEN_ROOT_DIR}/symbiflow_installer"
INGEN_CONDA_ENV__SYMBIFLOW_INSTALLER__ENV_YAML="${INGEN_SYMBIFLOW_INSTALLER_DIR}/environment.yml"
INGEN_CONDA_ENV__SYMBIFLOW_INSTALLER__REQ_TXT="${INGEN_SYMBIFLOW_INSTALLER_DIR}/requirements.txt" # we don't directly use, it is in the yml
INGEN_SYMBIFLOW_INSTALLER_CONDA_HELPER_SCRIPT="${INGEN_SYMBIFLOW_INSTALLER_DIR}/conda_helper.sh"
INGEN_SYMBIFLOW_INSTALLER_PACKAGE_UPDATES_YAML="${INGEN_SYMBIFLOW_INSTALLER_DIR}/package_updates.yml"
INGEN_SYMBIFLOW_INSTALLER_SCRIPT="${INGEN_SYMBIFLOW_INSTALLER_DIR}/symbiflow_installer.sh"
#INGEN_SYMBIFLOW_INSTALLER_ARCHIVE= # exported by the parent script!
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_LABEL="Quicklogic Symbiflow Package Installer"
# NOTE: the startup script name below and INGEN_SYMBIFLOW_INSTALLER_SCRIPT should be the same name!
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_STARTUP_SCRIPT="./symbiflow_installer.sh"


##########################################################################################
# parse args
##########################################################################################
# development settings: do not setup a fresh conda install/env, if it already exists!
DEVELOPMENT_MODE="dev"
DEVELOPMENT_MODE_ENABLED="$FALSE_VAL"

if [ $# == 1 ] ; then

    if [ $1 == "$DEVELOPMENT_MODE" ] ; then

        echo "[>> INGEN <<] DEV MODE specified!"
        DEVELOPMENT_MODE_ENABLED="$TRUE_VAL"

    fi

fi
##########################################################################################



##########################################################################################
# function : clean all the artifacts produced during the ingen process
##########################################################################################
function ingen_cleanup() {
    # cleanup the ingen_builder artifacts in the INGEN_BUILDER_DATA_DIR, if not in dev mode
    if [ "$DEVELOPMENT_MODE_ENABLED" == "$FALSE_VAL" ] ; then
        
        # check for existing builder data dir
        if [ -d "$INGEN_BUILDER_DATA_DIR" ] ; then

            # clean it up
            echo "[>> INGEN <<] clean up builder data in:" "$INGEN_BUILDER_DATA_DIR"
            rm -rf "$INGEN_BUILDER_DATA_DIR"

        fi
    fi


    # cleanup conda installation at the end, if not in dev mode
    if [ "$DEVELOPMENT_MODE_ENABLED" == "$FALSE_VAL" ] ; then

        # check for existing conda installation
        if [ -d "$INGEN_CONDA_INSTALL_DIR" ] ; then

            # clean it up
            echo "[>> INGEN <<] clean up existing conda installation in:" "$INGEN_CONDA_INSTALL_DIR"
            rm -rf "$INGEN_CONDA_INSTALL_DIR"

        fi

    fi
}
##########################################################################################



##########################################################################################
# STEP 1 : create a new local conda installation and configure it
##########################################################################################
# setup the conda install and configure it
if [ "$DEVELOPMENT_MODE_ENABLED" == "$TRUE_VAL" ] ; then

    # check for existing conda install
    if [ -d "$INGEN_CONDA_INSTALL_DIR" ] ; then

        # already exists, nothing do further to setup a new env in development mode
        echo "[>> INGEN <<] [DEV MODE] reusing existing conda install in:" "$INGEN_CONDA_INSTALL_DIR"

        # setup the conda installation path
        setup_local_conda_install_paths "$INGEN_CONDA_INSTALL_DIR"

    else

        # conda install dir does not exist
        echo "[>> INGEN <<] [DEV MODE] conda installation does not exist, create new conda install"

        # setup new conda install
        setup_local_conda_install "$INGEN_CONDA_INSTALL_DIR"

    fi

else # USER MODE, start fresh conda install always

    # check for existing conda install
    if [ -d "$INGEN_CONDA_INSTALL_DIR" ] ; then

        # clean it up
        echo "[>> INGEN <<] clean up existing conda env in:" "$INGEN_CONDA_INSTALL_DIR"
        rm -rf "$INGEN_CONDA_INSTALL_DIR"

    fi

    # setup new conda install
    setup_local_conda_install "$INGEN_CONDA_INSTALL_DIR"

fi
##########################################################################################



##########################################################################################
# STEP 2 : create the conda env for the installer generator process - 'ingen'
##########################################################################################
if [ "$DEVELOPMENT_MODE_ENABLED" == "$TRUE_VAL" ] ; then

    # check for existing conda environment
    if [ -d "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX" ] ; then

        # already exists, nothing do further to setup a new env in development mode
        echo "[>> INGEN <<] [DEV MODE] reusing existing conda env in:" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"

    else

        # conda env dir does not exist
        echo "[>> INGEN <<] [DEV MODE] conda installation does not exist, create new conda install"

        # create the ingen conda environment
        create_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX" "$INGEN_CONDA_ENV__INGEN__ENV_YAML"

    fi

else # USER MODE, start fresh conda env always

    # check for existing conda environment
    if [ -d "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX" ] ; then

        # clean it up
        echo "[>> INGEN <<] clean up existing conda env in:" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
        delete_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"

    fi

    # create the ingen conda environment
    create_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX" "$INGEN_CONDA_ENV__INGEN__ENV_YAML"

fi

# activate the ingen conda environment
conda activate "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"

# test the ingen conda env to check if it looks good
test_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"

if [ ! $? == 0 ] ; then

    echo
    echo "[>> INGEN <<] ERROR: test_local_conda_env failed, aborting."
    exit 1

fi
##########################################################################################



##########################################################################################
# STEP 3 : generate conda env configuration to replicate the final symbiflow package 
#          installer env - 'ingen_builder' (using the ingen package specification yaml)
##########################################################################################
# activate the ingen conda env
conda activate "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo
echo "[>> INGEN <<] conda env activated:"
echo "  $INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo


# create a dir to hold the builder data files (conda list, json list, env yaml, pip req txt)
if [ -d "$INGEN_BUILDER_DATA_DIR" ] ; then

    rm -rf "$INGEN_BUILDER_DATA_DIR"

fi

mkdir "$INGEN_BUILDER_DATA_DIR"

# generate the conda env config (env yaml, req txt) using the package spec yaml
python3 ./ingen_generate_conda_env_configuration.py \
            --ingen_package_yaml_file="$INGEN_PACKAGE_SPEC_YAML" \
            --conda_env_config_dir="$INGEN_BUILDER_DATA_DIR" \


# deactivate the ingen conda env
conda deactivate
echo
echo "[>> INGEN <<] conda env deactivated:"
echo "  $INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo
##########################################################################################



##########################################################################################
# STEP 4 : obtain conda/pip package info using the 'ingen_builder' conda env
#          - create conda env using the generated 'ingen_builder' configuration
#          - activate 'ingen_builder' conda env
#          - grab the conda/pip packages information from the conda env
#          - remove the conda env as it is no longer needed
##########################################################################################
# create a conda env using the generated conda env configuration files:
cd "$INGEN_BUILDER_DATA_DIR"

# create the ingen_builder conda environment
create_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX" "$INGEN_CONDA_ENV__INGEN_BUILDER__ENV_YAML"

# move back into the root dir after creation is done.
cd -

# test the ingen_builder conda env to check if it looks good
test_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX"

if [ ! $? == 0 ] ; then

    echo
    echo "[>> INGEN <<] ERROR: test_local_conda_env failed, aborting."
    exit 1

fi

# activate the ingen_builder conda env
conda activate "$INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX"

echo
echo "[>> INGEN <<] conda env activated:"
echo "  $INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX"
echo


# grab the conda packages information
conda list --json > "$INGEN_BUILDER_DATA_CONDA_PACKAGES_JSON"

# grab the pip packages information
pip list --format=json > "$INGEN_BUILDER_DATA_PIP_PACKAGES_JSON"


# deactivate the ingen_builder conda env
conda deactivate
echo
echo "[>> INGEN <<] conda env deactivated:"
echo "  $INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX"
echo

# remove the ingen_builder conda env
delete_local_conda_env "$INGEN_CONDA_INSTALL_DIR" "$INGEN_CONDA_ENV__INGEN_BUILDER__ENV_PREFIX"
##########################################################################################


# >> The next steps all will be executed in the 'ingen' conda env
# activate the ingen conda env
conda activate "$INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo
echo "[>> INGEN <<] conda env activated:"
echo "  $INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo


##########################################################################################
# STEP 5 : check for updates available for the symbiflow packages
#          - generate ingen package updates yaml using the information obtained from
#            the conda/pip packages information, and for the "gh" type packages from
#            the github repositories
#          - check if there are any updates available for 'relevant' packages according
#            to the rules in the ingen package spec yaml
##########################################################################################

# generate updates yaml using the package spec, conda packages json and pip packages json
# derived from the ingen_builder conda env creation process
python3 ./ingen_generate_package_updates.py \
            --package_spec_yaml_file="$INGEN_PACKAGE_SPEC_YAML" \
            --package_updates_yaml_file="$INGEN_PACKAGE_UPDATES_YAML" \
            --conda_packages_json_file="$INGEN_BUILDER_DATA_CONDA_PACKAGES_JSON" \
            --pip_packages_json_file="$INGEN_BUILDER_DATA_PIP_PACKAGES_JSON"

GENERATE_PACKAGE_UPDATES_STATUS=$?

if [ $GENERATE_PACKAGE_UPDATES_STATUS -ne 0 ] ; then

    echo
    echo "[>> INGEN <<] Generate Package Updates Failed!"
    echo "[>> INGEN <<] Aborting."
    ingen_cleanup
    exit 1

fi


# check if any updates available that we want? no(0) -> exit, yes(1) -> proceed.
python3 ./ingen_check_for_updates.py \
            --package_current_yaml_file="$INGEN_PACKAGE_CURRENT_YAML" \
            --package_updates_yaml_file="$INGEN_PACKAGE_UPDATES_YAML" \

PACKAGE_UPDATE_AVAILABLE=$?

if [ $PACKAGE_UPDATE_AVAILABLE == 0 ] ; then

    echo
    echo "[>> INGEN <<] No new updates are available for the Symbiflow Packages"
    echo "[>> INGEN <<] Exiting."
    ingen_cleanup
    exit 0

fi
##########################################################################################



##########################################################################################
# STEP 6 : prepare the final symbiflow package installer
#           - generate conda env configuration for the final symbiflow package 
#             installer env - (using the ingen package updates yaml)
#           - copy the required files for the installer (conda_helper script)
#           - copy other relevant files (package updates yaml for documentation)
#           - generate the symbiflow package installer script using the template script
#             and the "gh" package information from the ingen package updates yaml
#           - generate the self-extracting symbiflow package installer using the set of
#             files generated above
##########################################################################################

# create a dir to hold the symbiflow_installer files (env yaml, pip req txt, updates yaml ...)
if [ -d "$INGEN_SYMBIFLOW_INSTALLER_DIR" ] ; then

    rm -rf "$INGEN_SYMBIFLOW_INSTALLER_DIR"

fi

mkdir "$INGEN_SYMBIFLOW_INSTALLER_DIR"


# generate the conda env config (env yaml, req txt) using the package updates yaml
python3 ./ingen_generate_conda_env_configuration.py \
            --ingen_package_yaml_file="$INGEN_PACKAGE_UPDATES_YAML" \
            --conda_env_config_dir="$INGEN_SYMBIFLOW_INSTALLER_DIR" \

GENERATE_CONDA_ENV_CONFIG_STATUS=$?

if [ $GENERATE_CONDA_ENV_CONFIG_STATUS -ne 0 ] ; then

    echo
    echo "[>> INGEN <<] Generate Conda Env Configuration Failed!"
    echo "[>> INGEN <<] Aborting."
    ingen_cleanup
    exit 1

fi

# copy the package updates yaml file into the symbiflow_installer dir
cp -v "$INGEN_PACKAGE_UPDATES_YAML" "$INGEN_SYMBIFLOW_INSTALLER_PACKAGE_UPDATES_YAML"

# copy the conda helper script into the symbiflow_installer dir
cp -v "$INGEN_CONDA_HELPER_SCRIPT" "$INGEN_SYMBIFLOW_INSTALLER_CONDA_HELPER_SCRIPT"


# generate the symbiflow installer script from the template and files from the symbiflow_installer dir
python3 ./ingen_generate_installer_script.py \
            --ingen_package_yaml_file="$INGEN_PACKAGE_UPDATES_YAML" \
            --ingen_installer_script_template="$INGEN_INSTALLER_SCRIPT_TEMPLATE" \
            --ingen_installer_script_generated="$INGEN_SYMBIFLOW_INSTALLER_SCRIPT"

GENERATE_INSTALLER_SCRIPT_STATUS=$?

if [ $GENERATE_INSTALLER_SCRIPT_STATUS -ne 0 ] ; then

    echo
    echo "[>> INGEN <<] Generate Installer Script Failed!"
    echo "[>> INGEN <<] Aborting."
    ingen_cleanup
    exit 1

fi

# generate self-extracting installer from the symbiflow_installer dir
# use makeself-2.3.1 for compatibility reasons

# get makeself-2.3.1 from github releases (skipped because, we keep in the repo)
#wget -q https://github.com/megastep/makeself/releases/download/release-2.3.1/makeself-2.3.1.run

# install makeself
chmod +x makeself-2.3.1.run
./makeself-2.3.1.run -q 1>/dev/null
#rm -f makeself-2.3.1.run

# create symbiflow dailybuild installer
# makeself <archive_dir> <file_name> <label> <startup_script> [script_args]
./makeself-2.3.1/makeself.sh -q --gzip "$INGEN_SYMBIFLOW_INSTALLER_DIR" \
                                       "${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE}" \
                                       "${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_LABEL}" \
                                       "${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_STARTUP_SCRIPT}"

# remove makeself install
rm -rf ./makeself-2.3.1
##########################################################################################


# deactivate the ingen conda env
conda deactivate
echo
echo "[>> INGEN <<] conda env deactivated:"
echo "  $INGEN_CONDA_ENV__INGEN__ENV_PREFIX"
echo


# finally clean up everything:
ingen_cleanup

# exit
exit 0
