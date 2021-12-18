#!/bin/bash


# NOTE: ensure that this script is executed in a new, fresh shell!



# usage : bash ingen_test_package_installer.sh </path/to/package/installer> </temp/dir/for/installation> </path/to/sanity/tests>

SYMBIFLOW_PACKAGE_INSTALLER=$1
SYMBIFLOW_PACKAGE_INSTALL_DIR=$2
SYMBIFLOW_PACKAGE_TESTS_DIR=$3

TEST_STATUS=


##########################################################################################
# function : clean up the installation
##########################################################################################
function cleanup_with_exit_code() {

    exit_code=$1

    # clean the test installation directory
    rm -rf "$INSTALL_DIR"

    exit $((exit_code))
}
##########################################################################################


##########################################################################################
# STEP 1 : install and configure the Quicklogic Symbiflow Package using the installer
##########################################################################################

# set install location
export INSTALL_DIR="$SYMBIFLOW_PACKAGE_INSTALL_DIR"

# install using self extracting installer
chmod +x "${SYMBIFLOW_PACKAGE_INSTALLER}"
"${SYMBIFLOW_PACKAGE_INSTALLER}"

# configure the symbiflow package installation
cd "${INSTALL_DIR}"
source setup.sh
cd -
##########################################################################################


##########################################################################################
# STEP 2a : test the Quicklogic Symbiflow Package for k6n10
##########################################################################################
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_16bit"

ql_symbiflow -compile -src $PWD -d qlf_k6n10 -t top -v counter_16bit.v
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] TEST FAILED: qlf_k6n10"
    cleanup_with_exit_code 1

fi

cd -
##########################################################################################


##########################################################################################
# STEP 2b : test the Quicklogic Symbiflow Package for k4n8
##########################################################################################
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_16bit"

ql_symbiflow -compile -src $PWD -d qlf_k4n8 -t top -v counter_16bit.v
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] TEST FAILED: qlf_k4n8"
    cleanup_with_exit_code 1

fi

cd -
##########################################################################################


##########################################################################################
# STEP 2c : test the Quicklogic Symbiflow Package for ql-eos-s3
##########################################################################################
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_16bit"

ql_symbiflow -compile -src $PWD -d ql-eos-s3 -P PD64 -t top -v counter_16bit.v -p counter_16bit_chandalar.pcf -dump binary header jlink openocd
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] TEST FAILED: ql-eos-s3"
    cleanup_with_exit_code 1

fi

cd -
##########################################################################################


##########################################################################################
# STEP 2d : test the Quicklogic Symbiflow Package for pp3
##########################################################################################
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_8bit"

ql_symbiflow -compile -d ql-pp3 -v cnt8.v -t top -P WD30 -p WD30.pcf
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "[>> INGEN <<] TEST FAILED: pp3"
    cleanup_with_exit_code 1

fi

cd -
##########################################################################################

# All OK.
cleanup_with_exit_code 0
