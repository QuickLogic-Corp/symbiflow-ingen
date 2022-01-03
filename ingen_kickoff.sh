#!/bin/bash

##########################################################################################
# Quicklogic Symbiflow Package Installer Generator (InGen)
#
# Automated system to check for updates to all (relevant) components in the 
# Quicklogic Symbiflow Package and generate an installer
#
# prerequisites to be installed:
#   wget
#   git
#
# inputs: 
#   ingen_package_spec.yml (package specification yaml file)
# outputs: 
#   ql_symbiflow_package_installer_%DATE%.gz.run
#
# README.md has detailed desciption of the ingen workflow.
##########################################################################################

# export the env variables that we want all the other scripts to use

# note that this won't work with scripts in the PATH, but that is not what we are going for, right?
export INGEN_ROOT_DIR=$(cd `dirname $0` && pwd)
export INGEN_SCRIPTS_DIR="$INGEN_ROOT_DIR"

export CURRENT_DATE=$(date +%d_%b_%Y)
export CURRENT_TIME=$(date +"%H_%M_%S")

# path to generate the Symbiflow Package Installer
export INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME="symbiflow_dailybuild_$CURRENT_DATE.gz.run"
export INGEN_SYMBIFLOW_INSTALLER_ARCHIVE="${INGEN_ROOT_DIR}/${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME}"

export INGEN_PACKAGE_UPDATES_YAML="${INGEN_ROOT_DIR}/ingen_package_updates.yml"
export INGEN_PACKAGE_CURRENT_YAML="${INGEN_ROOT_DIR}/ingen_package_current.yml"

# publish path to keep final Symbiflow Package Installer after sanity
export INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH="${INGEN_ROOT_DIR}/installers/dailybuild/symbiflow_dailybuild_$CURRENT_DATE.gz.run"

# testing area to use for Symbiflow Package Installation (using the installer)
INGEN_SYMBIFLOW_TESTING__INSTALL_DIR="${INGEN_ROOT_DIR}/symbiflow_install_dir"
# location of 'sanity' tests
INGEN_SYMBIFLOW_TESTING__TESTS_DIR="${INGEN_ROOT_DIR}/tests"



echo
echo "[>> INGEN : Quicklogic Symbiflow Package Installer Generator <<]"
echo

echo
echo "[>> INGEN <<] kickoff: ${CURRENT_DATE} ${CURRENT_TIME} HRS"
echo



##########################################################################################
# PART A : Check for package updates, and generate a new Symbiflow Package Installer
##########################################################################################
echo
echo "[>> INGEN <<] generate package installer ... STARTED!"
echo

bash "${INGEN_ROOT_DIR}/ingen_generate_package_installer.sh" "dev"
INGEN_GENERATE_PACKAGE_INSTALLER_STATUS=$?

if [ $INGEN_GENERATE_PACKAGE_INSTALLER_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] generate package installer [OK]"

else

    echo
    echo "[>> INGEN <<] generate package installer [FAILED!]"
    exit 1

fi


##########################################################################################
# PART B : Use the Symbiflow Package Installer and run 'sanity' tests
##########################################################################################
# NOTE:The installation and tests of the package installer should be done in a new 
# bash shell context, so it does not have stuff in the current shell by ingen!

echo
echo "[>> INGEN <<] test package installer ... STARTED!"
echo

bash "${INGEN_ROOT_DIR}/ingen_test_package_installer.sh" "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE" \
                                                         "$INGEN_SYMBIFLOW_TESTING__INSTALL_DIR" \
                                                         "$INGEN_SYMBIFLOW_TESTING__TESTS_DIR"
INGEN_TEST_PACKAGE_INSTALLER_STATUS=$?

if [ $INGEN_TEST_PACKAGE_INSTALLER_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] test package installer ... [OK]"
    echo

else

    echo
    echo "[>> INGEN <<] test package installer ... [FAILED!]"
    echo
    exit 1

fi


# once tests ok, move the installer package into the release dir: installers/dailybuild
echo
echo "[>> INGEN <<] move final package installer :"
echo

mv -v "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE" "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH"


# the updates yaml becomes the new current yaml
echo
echo "[>> INGEN <<] update the corresponding final 'package current yaml' :"
echo

rm "$INGEN_PACKAGE_CURRENT_YAML"
mv -v "$INGEN_PACKAGE_UPDATES_YAML" "$INGEN_PACKAGE_CURRENT_YAML"


# the changelog txt is removed (leave it, as it is 'git'ignored)


exit 0

##########################################################################################
# PART C : Publish the Symbiflow Package Installer
##########################################################################################
echo
echo "[>> INGEN <<] publish package installer ... STARTED!"
echo

bash "${INGEN_ROOT_DIR}/ingen_publish_package_installer.sh" "github-actions"
INGEN_PUBLISH_PACKAGE_INSTALLER_STATUS=$?

if [ $INGEN_PUBLISH_PACKAGE_INSTALLER_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] publish package installer ... [OK]"
    echo

else

    echo
    echo "[>> INGEN <<] publish package installer ... [FAILED!]"
    echo
    exit 1

fi

##########################################################################################
# PART D : Run the full CI tests with the Symbiflow Package Installer
##########################################################################################
# TODO
# invoke regression script to execute device testing.
# this involves firing off the tests in a different repo and use the latest installer
# this infra needs a bit of changes before it can be integrated here.
