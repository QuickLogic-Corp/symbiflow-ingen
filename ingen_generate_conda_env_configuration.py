#!/usr/bin/env python3


# inputs :
#   package spec yaml (in ingen format)
#   conda env configuration dir (where to output the env yaml/requirements txt)
# process :
#   derive conda packages and their versions
#   derive pip packages and their versions
#   generate conda env configuration using these
# outputs:
#   conda environment yaml
#   pip requirements txt


# usage
# python3 ingen_generate_conda_env_configuration.py --package_spec_yaml_file=where --conda_env_config_dir=where

import argparse
import pathlib
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import SingleQuotedScalarString

##########################################################################################
# represent None type as 'null' from here: https://stackoverflow.com/a/57207057/3379867
def custom_represent_none(self, data):
    return self.represent_scalar(u'tag:yaml.org,2002:null', u'null')
##########################################################################################


def gen_env_config_from_package_spec(ingen_package_yaml_file, conda_env_config_dir):

    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.representer.add_representer(type(None), custom_represent_none)

    conda_environment_yaml_file_path=pathlib.Path(conda_env_config_dir, "environment.yml")
    pip_requirements_txt_file_path=pathlib.Path(conda_env_config_dir, "requirements.txt")

    with open(ingen_package_yaml_file, "r") as package_spec_yaml_stream:
        
        # read the package spec yaml
        ingen_package_yaml = yaml.load(package_spec_yaml_stream)

        # conda environment yaml initialize
        conda_environment_yaml = {}

        conda_environment_yaml['channels'] = []
        conda_environment_yaml['channels'].append('defaults')

        conda_environment_yaml['dependencies'] = []

        # always have python specified.
        conda_environment_yaml['dependencies'].append('python=3.7')

        # pip requirements txt list initialize
        pip_requirements_list = []


        for package_yaml in ingen_package_yaml["package_list"]:

            # packages that don't care about the version to be installed, we don't specify the version
            if (package_yaml["use-version"] == None):

                if(package_yaml["type"] == "conda"):
                    conda_environment_yaml['dependencies'].append(package_yaml['channel'] + '::' + package_yaml['name'])

                elif(package_yaml["type"] == "pip"):
                    pip_requirements_list.append(package_yaml['name'])

            # packages that want the latest version available to be installed:
            if (package_yaml["use-version"] == "latest"):

                # if there is no "latest-version" specified, or specified as null, we don't specify the version
                # this handles the scenario when the package_yaml_file is a "specification", like the ingen_package_spec.yml
                if ( ("latest-version" in package_yaml) and (package_yaml["latest-version"] != None) ):

                    if(package_yaml["type"] == "conda"):
                        conda_environment_yaml['dependencies'].append(package_yaml['channel'] + '::' + package_yaml['name'] + '=' + package_yaml['latest-version'])

                    elif(package_yaml["type"] == "pip"):
                        pip_requirements_list.append(package_yaml['name'] + '==' + package_yaml['latest-version'])
                
                # if the "latest-version" is specified, we specify this version to be installed
                # this handles the scenario when the package_yaml_file is a "directive", like the ingen_package_updates.yml
                else:

                    if(package_yaml["type"] == "conda"):
                        conda_environment_yaml['dependencies'].append(package_yaml['channel'] + '::' + package_yaml['name'])

                    elif(package_yaml["type"] == "pip"):
                        pip_requirements_list.append(package_yaml['name'])


            # packages that need to be pinned to a specific working version, we specify that version
            if (package_yaml["use-version"] == 'working'):

                if(package_yaml["type"] == "conda"):
                    conda_environment_yaml['dependencies'].append(package_yaml['channel'] + '::' + package_yaml['name'] + '=' + package_yaml['working-version'])

                elif(package_yaml["type"] == "pip"):
                    pip_requirements_list.append(package_yaml['name'] + '==' + package_yaml['working-version'])

        
        # safety net: if pip is not in the final list of conda packages in the yaml, ensure that we add it here!
        if ( ('pip' not in conda_environment_yaml['dependencies']) and
             ('defaults::pip' not in conda_environment_yaml['dependencies']) ) :
            
            conda_environment_yaml['dependencies'].append('pip')

        # add the pip dict at the end to match conda env yaml conventions
        # always use requirements.txt for pip packages
        pip_requirements_dict = {}
        pip_requirements_dict['pip'] = []
        pip_requirements_dict['pip'].append('-r requirements.txt')

        conda_environment_yaml['dependencies'].append(pip_requirements_dict)

                
        with open(conda_environment_yaml_file_path, "w") as conda_environment_yaml_stream, \
             open(pip_requirements_txt_file_path, "w") as pip_requirements_txt_stream :

            yaml.dump(conda_environment_yaml, conda_environment_yaml_stream)

            for pip_requirement in pip_requirements_list:

                pip_requirements_txt_stream.write(pip_requirement + '\n')

        print()
        print("generated conda env yaml:\n", conda_environment_yaml_file_path)
        print()
        print("generated pip requirements txt:\n", pip_requirements_txt_file_path)
        print()

    return


if (__name__ == "__main__"):

    parser = argparse.ArgumentParser(description='ingen package yaml to conda env config generator')

    parser.add_argument("--ingen_package_yaml_file", 
                        type=pathlib.Path, 
                        help="path to the (ingen format) package yaml file",
                        required=True)

    parser.add_argument("--conda_env_config_dir", 
                        type=pathlib.Path, 
                        help="path to the dir where conda env yaml and pip requirements txt should be generated",
                        required=True)


    args = parser.parse_args()

    gen_env_config_from_package_spec(ingen_package_yaml_file = args.ingen_package_yaml_file, 
                                     conda_env_config_dir = args.conda_env_config_dir)
