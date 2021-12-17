#!/usr/bin/env python3


# inputs :
#   package yaml (in ingen format)
#   installer template script
# process :
#   read package yaml
#   check for packages of type 'gh' and process them
#   other packages : 'conda' and 'pip' type packages are controlled using the
#                       environment.yml and the requirements.txt and the conda env.
#   create installation steps for all processed packages and generate installer script
# outputs:
#   symbiflow installer script meant be used alongwith 'environment.yml' and
#       'requirements.txt'
# exit value:
#   exit with value 1 if error, else with value 0


# usage
# python3 ingen_generate_installer_script.py --ingen_package_yaml_file=where --ingen_installer_script_template=where --ingen_installer_script_generated=where


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

def generate_installer_script(package_yaml_file, installer_script_template, installer_script_generated):

    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.representer.add_representer(type(None), custom_represent_none)

    script_commands = []

    with open(package_yaml_file, 'r') as package_yaml_stream:

        # read the package yaml
        packages_yaml = yaml.load(package_yaml_stream)

        for package_yaml in packages_yaml['package_list']:
            
            if(package_yaml['type'] == 'gh'):
            
                if(package_yaml['subtype'] == 'pip'):

                    if (package_yaml['use-version'] == 'working') :

                        repo_url = package_yaml['repo']
                        commit_sha1 = package_yaml['working-version']
                        comment_string = package_yaml['comment']

                    elif (package_yaml['use-version'] == 'latest') :

                        repo_url = package_yaml['repo']
                        commit_sha1 = package_yaml['latest-version']
                        comment_string = package_yaml['comment']

                    elif (package_yaml['use-version'] == None) :

                        repo_url = package_yaml['repo']
                        commit_sha1 = None
                        comment_string = None

                    # common handling for 'gh' -> 'pip' packages
                    command = ''
                    script_commands.append(command)
                    command = 'echo "" ; echo "" ;'
                    script_commands.append(command)
                    command = '# {comment}'.format(comment=comment_string)
                    script_commands.append(command)
                    command = 'pip install git+{repo}@{commit_id}'.format(repo=repo_url, commit_id=commit_sha1)
                    script_commands.append(command)

                elif(package_yaml['subtype'] == 'arch-defs'):

                    if (package_yaml['use-version'] == 'working') :

                        commit_sha1_short = package_yaml['working-version-short']
                        comment_string = package_yaml['comment']

                    elif (package_yaml['use-version'] == 'latest') :

                        commit_sha1_short = package_yaml['latest-version-short']
                        comment_string = package_yaml['comment']

                    else:

                        print()
                        print('ERROR: packages of type "arch-defs" cannot have "use-version" as "null"!')
                        print()
                        pprint(package_yaml)
                        print()

                        exit(1)

                    # common handling for 'gh' -> 'arch-defs' package
                    tarball_url = str(package_yaml['tarball-url-format']).replace('!!commit-sha1-short!!', commit_sha1_short)
                    command = ''
                    script_commands.append(command)
                    command = 'echo "" ; echo "" ;'
                    script_commands.append(command)
                    command = 'echo "download and extract arch-defs tarball ..."'
                    script_commands.append(command)
                    command = '# {comment}'.format(comment=comment_string)
                    script_commands.append(command)
                    # TODO: seeing intermittent dns failures - add retry
                    command = 'curl {tarball} --output arch.tar.gz'.format(tarball=tarball_url)
                    script_commands.append(command)
                    command = 'tar -C $INSTALL_DIR -xf arch.tar.gz && rm arch.tar.gz'
                    script_commands.append(command)

        # end of package loop

        # add all the generated script commands into the template script file at the
        # designated location

        with open(installer_script_template, 'r') as script_template_stream, \
             open(installer_script_generated, 'w') as script_generated_stream:

            for line in script_template_stream:

                # designated location
                if(line.__contains__('!!INGEN TEMPLATE PLACEHOLDER!!')):

                    # insert the generated commands here.
                    for command_string in script_commands:
                        script_generated_stream.write(command_string + '\n')

                else:

                    script_generated_stream.write(line)

    # end of package yaml file processing



if (__name__ == '__main__'):

    parser = argparse.ArgumentParser(description='generate final installer script from package yaml and template script')

    parser.add_argument('--ingen_package_yaml_file', 
                        type=pathlib.Path, 
                        help='path to the (ingen format) package (updates) yaml file',
                        required=True)

    parser.add_argument('--ingen_installer_script_template', 
                        type=pathlib.Path, 
                        help='path to the installer script template',
                        required=True)

    parser.add_argument('--ingen_installer_script_generated', 
                        type=pathlib.Path, 
                        help='path to generate the final installer script from the template',
                        required=True)


    args = parser.parse_args()

    return_val = generate_installer_script(package_yaml_file = args.ingen_package_yaml_file,
                                           installer_script_template = args.ingen_installer_script_template,
                                           installer_script_generated = args.ingen_installer_script_generated)

    sys.exit(return_val)
