#!/bin/bash


# testing purposes
INGEN_ROOT_DIR="$PWD"
INGEN_SYMBIFLOW_TESTING__INSTALL_DIR="${INGEN_ROOT_DIR}/symbiflow_install_dir"
INGEN_SYMBIFLOW_TESTING__TESTS_DIR="${INGEN_ROOT_DIR}/tests"

CURRENT_DATE=$(date +%d_%b_%Y)
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE="${INGEN_ROOT_DIR}/symbiflow_dailybuild_$CURRENT_DATE.gz.run"


bash ./ingen_harness.sh
INGEN_STATUS=$?

if [ $INGEN_STATUS == 0 ] ; then

    echo
    echo "INGEN Successful"

else

    echo
    echo "!!! INGEN FAILED !!!"
    exit 1

fi

##########################################################################################
# STEP 7 : sanity test the self-extracting symbiflow package installer
##########################################################################################

# note that the installation and tests of the package installer should be done in a new 
# bash shell context, so it does not have stuff in the current shell by ingen!

bash ./ingen_test_installer.sh "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE" "$INGEN_SYMBIFLOW_TESTING__INSTALL_DIR" "$INGEN_SYMBIFLOW_TESTING__TESTS_DIR"
TEST_STATUS=$?

if [ $TEST_STATUS == 0 ] ; then

    echo
    echo "Test PASSED"
    echo "Exiting Ingen"
    exit 0

else

    echo
    echo "!!! Test FAILED !!!"
    echo "Exiting Ingen"
    exit 1

fi
##########################################################################################