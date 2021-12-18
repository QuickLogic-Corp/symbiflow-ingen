#!/bin/bash

##########################################################################################
# Quicklogic Symbiflow Package Installer Generator (InGen)
#
# Automated system to check for updates to all (relevant) components in the 
# Quicklogic Symbiflow Package and generate an installer
#
# inputs: 
#   ingen_package_spec.yml (package specification yaml file)
# outputs: 
#   ql_symbiflow_package_installer_%DATE%.gz.run
#
# README.md has detailed desciption of the ingen workflow.
##########################################################################################

# export the env variables that we want all the other scripts to use

export INGEN_ROOT_DIR="$PWD"
export INGEN_SCRIPTS_DIR="$INGEN_ROOT_DIR"

export CURRENT_DATE=$(date +%d_%b_%Y)
export CURRENT_TIME=$(date +"%H_%M_%S")

# path to generate the Symbiflow Package Installer
export INGEN_SYMBIFLOW_INSTALLER_ARCHIVE="${INGEN_ROOT_DIR}/symbiflow_dailybuild_$CURRENT_DATE.gz.run"


# testing area to use for Symbiflow Package Installation (using the installer)
INGEN_SYMBIFLOW_TESTING__INSTALL_DIR="${INGEN_ROOT_DIR}/symbiflow_install_dir"
# location of 'sanity' tests
INGEN_SYMBIFLOW_TESTING__TESTS_DIR="${INGEN_ROOT_DIR}/tests"



echo
echo "[>> INGEN : Quicklogic Symbiflow Package Installer Generator <<]"
echo

echo
echo "[>> INGEN <<] KickOff: ${CURRENT_DATE} ${CURRENT_TIME} HRS"
echo



##########################################################################################
# PART A : Check for package updates, and generate a new Symbiflow Package Installer
##########################################################################################
echo
echo "[>> INGEN <<] Generate Package Installer ... STARTED!"

bash "${INGEN_ROOT_DIR}/ingen_generate_package_installer.sh"
INGEN_GENERATE_PACKAGE_INSTALLER_STATUS=$?

if [ $INGEN_GENERATE_PACKAGE_INSTALLER_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] Generate Package Installer ... OK."

else

    echo
    echo "[>> INGEN <<] Generate Package Installer ... FAILED!"
    exit 1

fi


##########################################################################################
# PART B : Use the Symbiflow Package Installer and run 'sanity' tests
##########################################################################################
# NOTE:The installation and tests of the package installer should be done in a new 
# bash shell context, so it does not have stuff in the current shell by ingen!

echo
echo "[>> INGEN <<] Test Package Installer ... STARTED!"

bash "${INGEN_ROOT_DIR}/ingen_test_package_installer.sh" "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE" \
                                                         "$INGEN_SYMBIFLOW_TESTING__INSTALL_DIR" \
                                                         "$INGEN_SYMBIFLOW_TESTING__TESTS_DIR"
INGEN_TEST_PACKAGE_INSTALLER_STATUS=$?

if [ $INGEN_TEST_PACKAGE_INSTALLER_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] Test Package Installer ... OK."

else

    echo
    echo "[>> INGEN <<] Test Package Installer ... FAILED!"
    exit 1

fi


##########################################################################################
# PART C : Publish the Symbiflow Package Installer
##########################################################################################
#TODO


##########################################################################################
# PART D : Run the full CI tests with the Symbiflow Package Installer
##########################################################################################
#TODO
