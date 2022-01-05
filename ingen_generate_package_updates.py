#!/usr/bin/env python3


# inputs :
#   package spec yaml (in ingen format)
#   conda packages json file (generated from the builder conda env)
#   pip packages json file (generated from the builder conda env)
#   package updates yaml file path (to be written)
# process :
#   read package spec
#   get versions of all conda/pip packages from conda/pip json file from builder conda env
#   get versions of all gh packages from gh, arch-defs-tarball url from storage url
# outputs:
#   package updates yaml file


# usage
# python3 ingen_generate_package_updates.py --package_spec_yaml_file=where --package_updates_yaml_file=where --conda_packages_json_file=where --pip_packages_json_file=where


import argparse
import pathlib
from pprint import pprint
from ruamel.yaml import YAML
from ruamel.yaml.scalarstring import SingleQuotedScalarString
import json
import subprocess
import requests

##########################################################################################
# represent None type as 'null' from here: https://stackoverflow.com/a/57207057/3379867
def custom_represent_none(self, data):
    return self.represent_scalar(u'tag:yaml.org,2002:null', u'null')
##########################################################################################


##########################################################################################
def git_get_latest_commits(repo, branch, num_commits):

    proc = subprocess.run(['./ingen_git_get_commit_list.sh', repo, branch, str(num_commits)],
               text=True, capture_output=True)

    #pprint(proc.stdout)
    return json.loads(proc.stdout)


def git_get_latest_commit(repo, branch):

    # get the commit history, limit to last 1 commit from the git repo
    commits_json = git_get_latest_commits(repo, branch, 1)
    
    # extract the first entry and return that
    latest_commit_json = commits_json['commits'][0]
    latest_commit_sha1 = latest_commit_json['sha1']
    latest_commit_sha1_short = latest_commit_json['sha1-short']
    latest_commit_log = latest_commit_json['log']

    print()
    print('-------------------')
    print(repo)
    print(branch)
    print(latest_commit_sha1)
    print(latest_commit_sha1_short)
    print(latest_commit_log)
    print('-------------------')
    print()

    return latest_commit_json


def test__git_get_latest_commits():

    commits_json = git_get_latest_commits('https://github.com/QuickLogic-Corp/symbiflow-arch-defs',
                                                            'master',
                                                            10)

    pprint(commits_json)


def test__git_get_latest_commit():

    latest_commit_json = git_get_latest_commit('https://github.com/QuickLogic-Corp/symbiflow-arch-defs',
                                                            'master')

    latest_commit_json = git_get_latest_commit('https://github.com/QuickLogic-Corp/symbiflow-arch-defs',
                                                            'quicklogic-upstream-rebase')

    latest_commit_json = git_get_latest_commit('https://github.com/QuickLogic-Corp/ql_fasm',
                                                            'master')

    latest_commit_json = git_get_latest_commit('https://github.com/QuickLogic-Corp/quicklogic-fasm',
                                                            'master')
##########################################################################################


##########################################################################################
def arch_defs_package_get_latest_commit(repo, branch):

    latest_commit_json = None

    commits_json = git_get_latest_commits(repo, branch, 10)

    for commit_json in commits_json['commits']:

        commit_sha1_short = commit_json['sha1-short']
        arch_defs_tarball_url = f'https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-{commit_sha1_short}.tar.gz'

        http_response = requests.head(arch_defs_tarball_url, timeout=5)
        # pprint(http_response.headers)

        tarball_url_status_code = http_response.status_code
        tarball_url_content_type = http_response.headers.get('content-type')
        tarball_url_content_length = http_response.headers.get('content-length')
        # print(tarball_url_status_code)
        # print(tarball_url_content_type)
        # print(tarball_url_content_length)
        # print()

        if(tarball_url_status_code == 200 and 
            tarball_url_content_type == 'application/x-tar'):

            latest_commit_json = commit_json

            break

    latest_commit_sha1 = latest_commit_json['sha1']
    latest_commit_sha1_short = latest_commit_json['sha1-short']
    latest_commit_log = latest_commit_json['log']


    print()
    print('-------------------')
    print(repo)
    print(branch)
    print(latest_commit_sha1)
    print(latest_commit_sha1_short)
    print(latest_commit_log)
    print('-------------------')
    print()   

    return latest_commit_json


def test__arch_defs_package_get_latest_version():

    arch_defs_package_get_latest_commit('https://github.com/QuickLogic-Corp/symbiflow-arch-defs', 'master')

    arch_defs_package_get_latest_commit('https://github.com/QuickLogic-Corp/symbiflow-arch-defs', 'quicklogic-upstream-rebase')
##########################################################################################


##########################################################################################
def conda_get_package_from_json(name, conda_packages_json):
    
    # example obj format returned:
    # {
    #     'base_url': 'https://conda.anaconda.org/litex-hub/label/main',
    #     'build_number': 20211214154543,
    #     'build_string': '20211214_154543_py37',
    #     'channel': 'litex-hub/label/main',
    #     'dist_name': 'yosys-0.12_30_g5dadcc85b-20211214_154543_py37',
    #     'name': 'yosys',
    #     'platform': 'linux-64',
    #     'version': '0.12_30_g5dadcc85b'
    # },

    package_json = [obj for obj in conda_packages_json if obj['name']==name][0]
    
    print()
    print('-------------------')
    print(package_json['name'])
    print(package_json['channel'])
    print(package_json['version'])
    print('-------------------')
    print()

    return package_json
##########################################################################################


##########################################################################################
def pip_get_package_from_json(name, pip_packages_json):

    # example obj format returned:
    # {'name': 'serial', 'version': '0.0.97'}

    package_json = [obj for obj in pip_packages_json if obj['name']==name][0]

    print()
    print('-------------------')
    print(package_json['name'])
    print(package_json['version'])
    print('-------------------')
    print()

    return package_json
##########################################################################################


def gen_package_updates_from_package_spec(package_spec_yaml_file,
                                          conda_packages_json_file,
                                          pip_packages_json_file,
                                          package_updates_yaml_file):

    # load the conda packages json file:
    conda_packages_json = None
    with open(conda_packages_json_file, 'r') as conda_packages_json_stream:
        conda_packages_json = json.load(conda_packages_json_stream)


    # load the pip packages json file:
    pip_packages_json = None
    with open(pip_packages_json_file, 'r') as pip_packages_json_stream:
        pip_packages_json = json.load(pip_packages_json_stream)


    yaml = YAML()
    yaml.preserve_quotes = True
    yaml.representer.add_representer(type(None), custom_represent_none)

    with open(package_spec_yaml_file, 'r') as package_spec_yaml_stream:

        # read the package spec yaml
        package_spec_yaml = yaml.load(package_spec_yaml_stream)

        for package_yaml in package_spec_yaml['package_list']:

            if (package_yaml['use-version'] == 'working') :

                print()
                print('-------------------')
                print(package_yaml['name'], '[SKIPPED]')
                print('this package should *not* be updated')
                print(package_yaml['channel'])
                print(package_yaml['working-version'])
                print('-------------------')
                print()

            elif ( (package_yaml['use-version'] == 'latest') or
                   (package_yaml['use-version'] == None) ):

                if(package_yaml['type'] == 'conda'):

                    latest_package_json = conda_get_package_from_json(package_yaml['name'], conda_packages_json)
                    
                    latest_version = latest_package_json['version']
                    
                    package_yaml['latest-version'] = SingleQuotedScalarString(latest_version)

                    # for conda packages of subtype 'gh-ci', we can get the commit URL corresponding 
                    # to the conda version :
                    if(package_yaml['subtype'] == 'gh-ci'):
                        #x.y.z_AA_versionstring_gXXXXXXXX -> split('_') -> get last element -> strip the 'g' -> sha1 (short)
                        gh_commit_sha1 = latest_version.split('_')[-1].replace('g','')
                        gh_commit_url = package_yaml['repo'] + '/commit/' + gh_commit_sha1

                        # add this url to the comment field
                        package_yaml['comment'] = SingleQuotedScalarString(gh_commit_url)

                elif(package_yaml['type'] == 'pip'):

                    latest_package_json = pip_get_package_from_json(package_yaml['name'], pip_packages_json)
                    
                    latest_version = latest_package_json['version']

                    package_yaml['latest-version'] = SingleQuotedScalarString(latest_version)

                elif(package_yaml['type'] == 'gh'):

                    # use github repos for package, we have 2 categories as of now
                    # pip : use repo and install using pip (get source, build wheel, install)
                    # arch-defs : use repo, get corresponding tarball url, download, extract
                    # so our version strategy would be:
                    # (1) pip:
                    # get the commit SHA1 of the specified branch of the repo, and this will
                    # be our version to use
                    # (2) arch-defs:
                    # get the latest commit SHA1 of the specified branch which has a 
                    # corresponding tarball URL (not all do!),and this will be our version

                    if(package_yaml['subtype'] == 'pip'):

                        latest_commit_json = git_get_latest_commit(package_yaml['repo'],
                                                                   package_yaml['branch'])
                        latest_commit_sha1 = latest_commit_json['sha1']
                        latest_commit_log = latest_commit_json['log']
                        
                        package_yaml['latest-version'] = SingleQuotedScalarString(latest_commit_sha1)
                        package_yaml['comment'] = SingleQuotedScalarString(latest_commit_log)

                    elif(package_yaml['subtype'] == 'arch-defs'):

                        latest_commit_json = arch_defs_package_get_latest_commit(package_yaml['repo'],
                                                                                 package_yaml['branch'])
                        latest_commit_sha1 = latest_commit_json['sha1']
                        latest_commit_sha1_short = latest_commit_json['sha1-short']
                        latest_commit_log = latest_commit_json['log']

                        package_yaml['latest-version'] = SingleQuotedScalarString(latest_commit_sha1)
                        package_yaml['latest-version-short'] = SingleQuotedScalarString(latest_commit_sha1_short)
                        package_yaml['comment'] = SingleQuotedScalarString(latest_commit_log)

                    else:

                        print('ERROR: Unknown subtype!')
                        print()
                        pprint(package_yaml)

                else:

                    print('ERROR: unknown package type in spec!')
                    print()
                    pprint(package_yaml)

        
        # update the name of the 'file'
        package_spec_yaml['name'] = 'ingen_package_updates.yml'

        with open(package_updates_yaml_file, 'w') as stream:

            yaml.dump(package_spec_yaml, stream)



if (__name__ == '__main__'):

    parser = argparse.ArgumentParser(description='ingen package spec to ingen package updates generator')

    parser.add_argument('--package_spec_yaml_file', 
                        type=pathlib.Path, 
                        help='path to the (ingen format) package spec yaml file',
                        required=True)

    parser.add_argument('--conda_packages_json_file', 
                        type=pathlib.Path, 
                        help='path to the conda packages json file from the ingen builder conda env',
                        required=True)

    parser.add_argument('--pip_packages_json_file', 
                        type=pathlib.Path, 
                        help='path to the pip packages json file from the ingen builder conda env',
                        required=True)

    parser.add_argument('--package_updates_yaml_file', 
                        type=pathlib.Path, 
                        help='path to write the (ingen format) package updates yaml file',
                        required=True)


    args = parser.parse_args()

    gen_package_updates_from_package_spec(package_spec_yaml_file = args.package_spec_yaml_file,
                                          conda_packages_json_file = args.conda_packages_json_file,
                                          pip_packages_json_file = args.pip_packages_json_file,
                                          package_updates_yaml_file = args.package_updates_yaml_file)
