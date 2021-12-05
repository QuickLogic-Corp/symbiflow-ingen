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

# save the current directory into a variable (TMP directory)
CURRENT_DIR=$(pwd)
echo "current directory is:" "$CURRENT_DIR"

# create install directory
mkdir -p $INSTALL_DIR

# get conda, configure and update
wget https://repo.anaconda.com/miniconda/Miniconda3-py37_4.10.3-Linux-x86_64.sh -O conda_installer.sh
bash conda_installer.sh -b -p $INSTALL_DIR/conda && rm conda_installer.sh
source "$INSTALL_DIR/conda/etc/profile.d/conda.sh"
echo "include-system-site-packages=false" >> $INSTALL_DIR/conda/pyvenv.cfg
CONDA_FLAGS="-y --override-channels -c defaults -c conda-forge"
conda update $CONDA_FLAGS -q conda

# activate the conda environment early
conda activate

# install our required packages
# refer to https://github.com/hdl/conda-eda/blob/master/syn/yosys/meta.yaml
# from conda packages:  https://anaconda.org/LiteX-Hub/yosys/files?channel=main
conda install $CONDA_FLAGS -c litex-hub/label/main yosys

# refer to https://github.com/hdl/conda-eda/blob/master/syn/yosys-plugins-symbiflow/meta.yaml
# from conda packages:  https://anaconda.org/LiteX-Hub/yosys-symbiflow-plugins/files?channel=main
conda install $CONDA_FLAGS -c litex-hub/label/main yosys-symbiflow-plugins

# refer to https://github.com/hdl/conda-eda/blob/master/pnr/vtr-optimized/meta.yaml
# correlate to: https://github.com/verilog-to-routing/vtr-verilog-to-routing/commit/06317d042
conda install $CONDA_FLAGS -c litex-hub/label/main vtr-optimized="8.0.0_4118_g06317d042"

conda install $CONDA_FLAGS -c litex-hub iverilog

conda install $CONDA_FLAGS -c tfors gtkwave

conda install $CONDA_FLAGS make lxml simplejson intervaltree git pip curl


################################################################################
# fixed version as of 05 OCTOBER 2021:
#sha1=12d521e
# fixed version as of 20 OCTOBER 2021:
#sha1=ec22e1c
#echo "DailyBuild Package: quicklogic-arch-defs-qlf-${sha1}.tar.gz"
#curl https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-${sha1}.tar.gz --output arch.tar.gz
#
#
################################################################################
# section to figure out the quicklogic-arch-defs archive path
cd $INSTALL_DIR
git clone --bare https://github.com/QuickLogic-Corp/symbiflow-arch-defs symbiflow-arch-defs
cd $INSTALL_DIR/symbiflow-arch-defs
VALID_COMMIT_SHA_FOUND=0
NUM_FALLBACK_COMMITS=10
COMMIT_i=0
HTTP_RESPONSE_OK="HTTP/2 200"
HTTP_1_1_PROXY_EXTRA_HEADER="HTTP/1.1 200 Connection established"
HTTP_1_0_PROXY_EXTRA_HEADER="HTTP/1.0 200 Connection established"
TAR_CONTENT_TYPE_HEADER="content-type: application/x-tar"
VALID_ARCH_DEFS_TAR_URL=""
# check last few commits and see if there is a corresponding arch-defs tar generated:
while [ $COMMIT_i -lt $NUM_FALLBACK_COMMITS ]
do
    
    # the workflow generated .tar.gz uses first 7 characters for SHA1 - this is git default (for "normal" sized repo history)
    # however, as the repo grows, this can be higher, it is 8 right now for our repo.
    # revisit this and sync with the workflow to use 8 or higher to prevent possible collisions.
    SHA1=$(git rev-parse HEAD~$COMMIT_i | cut -c1-7)
    #echo "checking commit:" $SHA1
    
    ARCH_DEFS_TAR_URL=https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-$SHA1.tar.gz
    #echo $ARCH_DEFS_TAR_URL
    
    # get full http response to check SSL/TLS proxy extra headers!
    HTTP_RESPONSE=$(curl --head --silent $ARCH_DEFS_TAR_URL)
    
    # remove any extra headers that may appear due to SSL/TLS proxy
    HTTP_RESPONSE="${HTTP_RESPONSE//$HTTP_1_1_PROXY_EXTRA_HEADER/""}"
    HTTP_RESPONSE="${HTTP_RESPONSE//$HTTP_1_0_PROXY_EXTRA_HEADER/""}"
    
    #echo "got http response:" $HTTP_RESPONSE
    
    if [[ "$HTTP_RESPONSE" =~ "$HTTP_RESPONSE_OK" ]] ;
    #if [[ "$HTTP_RESPONSE" =~ "$HTTP_RESPONSE_OK" ]] && [[ "$HTTP_RESPONSE" =~ "$TAR_CONTENT_TYPE_HEADER" ]] ;
    then
        echo "using:" $ARCH_DEFS_TAR_URL
        echo
        VALID_ARCH_DEFS_TAR_URL=$ARCH_DEFS_TAR_URL
        break
    else
        echo $ARCH_DEFS_TAR_URL "does not exist!"
        echo "try the next commit SHA-1!"
        echo
    fi
    
    # try the previous commit
    COMMIT_i=$((COMMIT_i+1))
done

# remove the bare git clone directory
cd $INSTALL_DIR
rm -rf $INSTALL_DIR/symbiflow-arch-defs

# check if we got a valid arch-defs archive:
if [ -z "$VALID_ARCH_DEFS_TAR_URL" ];
then
    echo "No Valid URL for the quicklogic-arch-defs archive was found!"
    echo "This is a FATAL error, exiting"
    exit 1
fi

# if all ok, go ahead and use the arch-defs tar using the $VALID_ARCH_DEFS_TAR_URL value
################################################################################

# extract arch-defs
curl $VALID_ARCH_DEFS_TAR_URL --output arch.tar.gz
tar -C $INSTALL_DIR -xvf arch.tar.gz && rm arch.tar.gz

# python packages
pip install python-constraint
pip install serial
pip install git+https://github.com/QuickLogic-Corp/ql_fasm
pip install git+https://github.com/QuickLogic-Corp/quicklogic-fasm


# create setup script for setting up conda env for package usage
setup_file=$INSTALL_DIR/setup.sh

echo "export INSTALL_DIR=$INSTALL_DIR" >$setup_file
#adding symbiflow toolchain binaries to PATH
echo "export PATH=\"\$INSTALL_DIR/quicklogic-arch-defs/bin:\$INSTALL_DIR/quicklogic-arch-defs/bin/python:\$PATH\"" >>$setup_file
echo "source \"\$INSTALL_DIR/conda/etc/profile.d/conda.sh\"" >>$setup_file
echo "conda activate" >>$setup_file

chmod 755 $setup_file

# run basic test for k6n10 to ensure everything is ok?

# deactivate the conda env now.
conda deactivate

# done.