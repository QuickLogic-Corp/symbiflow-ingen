#!/bin/bash

# NOTE: ensure that this script is executed in a new, fresh shell!

SYMBIFLOW_PACKAGE_INSTALLER=$1
SYMBIFLOW_PACKAGE_INSTALL_DIR=$2
SYMBIFLOW_PACKAGE_TESTS_DIR=$3


function cleanup_with_exit_code() {

    exit_code=$1

    # clean the test installation directory
    rm -rf "$INSTALL_DIR"

    exit $((exit_code))
}


# install using self extracting installer
export INSTALL_DIR="$SYMBIFLOW_PACKAGE_INSTALL_DIR"

chmod +x "${SYMBIFLOW_PACKAGE_INSTALLER}"
"${SYMBIFLOW_PACKAGE_INSTALLER}"


# configure the symbiflow package installation
cd "${INSTALL_DIR}"
source setup.sh
cd -


TEST_STATUS=1


#k6n10
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_16bit"

ql_symbiflow -compile -src $PWD -d qlf_k6n10 -t top -v counter_16bit.v
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "TEST FAILED: qlf_k6n10"
    cleanup_with_exit_code 1

fi


#k4n8
ql_symbiflow -compile -src $PWD -d qlf_k4n8 -t top -v counter_16bit.v
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "TEST FAILED: qlf_k4n8"
    cleanup_with_exit_code 1

fi


# ql-eos-s3
ql_symbiflow -compile -src $PWD -d ql-eos-s3 -P PD64 -t top -v counter_16bit.v -p counter_16bit_chandalar.pcf -dump binary header jlink openocd
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "TEST FAILED: ql-eos-s3"
    cleanup_with_exit_code 1

fi

cd -


# pp3
cd "$SYMBIFLOW_PACKAGE_TESTS_DIR/counter_8bit"

ql_symbiflow -compile -d ql-pp3 -v cnt8.v -t top -P WD30 -p WD30.pcf
TEST_STATUS=$?
rm -rf build/ Makefile.symbiflow

if [ ! $TEST_STATUS == 0 ] ; then

    echo
    echo "TEST FAILED: pp3"
    cleanup_with_exit_code 1

fi

cd -

cleanup_with_exit_code 0

