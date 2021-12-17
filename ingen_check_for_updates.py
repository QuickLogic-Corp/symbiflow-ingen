#!/usr/bin/env python3


# inputs :
#   package updates yaml (in ingen format)
#   package current yaml (in ingen format)
# process :
#   read package updates and package current yaml
#   if package current yaml does not exist, we have updates
#   if there are updates to "use-version:latest" or "use-version:working" packages
#       in the "latest-version" or "package-version" respectively, we have updates
# outputs:
#   exit with value 1 if we have updates, else with value 0


# usage
# python3 ingen_check_for_updates.py --package_current_yaml_file=where --package_updates_yaml_file=where
# use return value of the script 0 (no updates) or 1 (updates available)

import argparse
import pathlib
from pprint import pprint
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import SingleQuotedScalarString
import pathlib
import json
import subprocess
import requests
import sys

##########################################################################################
# represent None type as 'null' from here: https://stackoverflow.com/a/57207057/3379867
def custom_represent_none(self, data):
    return self.represent_scalar(u'tag:yaml.org,2002:null', u'null')
##########################################################################################

updates_available = 1
no_updates = 0

def get_package_yaml_from(package_file_yaml, ref_package_yaml):

    for package_yaml in package_file_yaml["package_list"]:

        if( (package_yaml['type'] == ref_package_yaml['type']) and
            (package_yaml['subtype'] == ref_package_yaml['subtype']) ):

            # we have 'name' for conda/pip packages
            # we have 'repo' for gh packages
            if(package_yaml["type"] == 'gh'):

                if(package_yaml['repo'] == ref_package_yaml['repo']):

                    return package_yaml

            else:

                if(package_yaml['name'] == ref_package_yaml['name']):

                    return package_yaml
            


    # if we get here, then the ref_package_yaml does not exist in the package_file_yaml
    return None



def check_for_updates(package_current_yaml_file,
                      package_updates_yaml_file):

    if(not pathlib.Path(package_current_yaml_file).is_file()):

        print()
        print("package_current_yaml_file does not exist: {file} ".format(file=package_current_yaml_file))
        print(" and we have a new package_updates_yaml_file")
        print()
        return updates_available

    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.representer.add_representer(type(None), custom_represent_none)

    with open(package_current_yaml_file, "r") as package_current_yaml_stream, \
         open(package_updates_yaml_file, "r") as package_updates_yaml_stream:

        # read the package spec yaml
        package_current_yaml = yaml.load(package_current_yaml_stream)
        package_updates_yaml = yaml.load(package_updates_yaml_stream)

        for package_yaml in package_updates_yaml["package_list"]:

            # find the same package in the package_current_yaml:
            package_c_yaml = get_package_yaml_from(package_file_yaml=package_current_yaml, ref_package_yaml=package_yaml)

            if(package_c_yaml == None):
                # as there is a new package in the updates yaml, we do have updates available.

                print()
                print("-------------------")
                print(package_yaml["type"])
                print(package_yaml['subtype'])
                if(package_yaml["type"] == 'gh'):
                    print(package_yaml["repo"], "[NEW PACKAGE]")
                else:
                    print(package_yaml["name"], "[NEW PACKAGE]")
                print("-------------------")
                print()

                return updates_available

            if (package_yaml["use-version"] == 'working') :

                if(package_yaml['working-version'] != package_c_yaml['working-version']):

                    print()
                    print("-------------------")
                    print(package_yaml["type"])
                    print(package_yaml['subtype'])
                    if(package_yaml["type"] == 'gh'):
                        print(package_yaml["repo"], "[NEW WORKING-VERSION]")
                    else:
                        print(package_yaml["name"], "[NEW WORKING-VERSION]")
                    print("was:",package_c_yaml['working-version'])
                    print("now:",package_yaml['working-version'])
                    print("-------------------")
                    print()

                    return updates_available

            elif (package_yaml["use-version"] == 'latest'):

                if(package_yaml['latest-version'] != package_c_yaml['latest-version']):

                    print()
                    print("-------------------")
                    print(package_yaml["type"])
                    print(package_yaml['subtype'])
                    if(package_yaml["type"] == 'gh'):
                        print(package_yaml["repo"], "[NEW LATEST-VERSION]")
                    else:
                        print(package_yaml["name"], "[NEW LATEST-VERSION]")
                    print("was:",package_c_yaml['latest-version'])
                    print("now:",package_yaml['latest-version'])
                    print("-------------------")
                    print()

                    return updates_available

        # if we exit out of the check loop, then we don't have any updates
        return no_updates


if (__name__ == "__main__"):

    parser = argparse.ArgumentParser(description='check for relevant updates in package versions')

    parser.add_argument("--package_current_yaml_file", 
                        type=pathlib.Path, 
                        help="path to the (ingen format) package current yaml file",
                        required=True)

    parser.add_argument("--package_updates_yaml_file", 
                        type=pathlib.Path, 
                        help="path to write the (ingen format) package updates yaml file",
                        required=True)


    args = parser.parse_args()

    return_val = check_for_updates(package_current_yaml_file = args.package_current_yaml_file,
                                   package_updates_yaml_file = args.package_updates_yaml_file)

    if(return_val == updates_available):
        print()
        print("updates available!")
    else:
        print()
        print("no updates!")

    sys.exit(return_val)
