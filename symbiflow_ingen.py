#!/usr/bin/env python3

# symbiflow in(staller)gen(erator)
# NOTE: this python script assumes that it will be running in 
# a terminal session where conda has already been configured and activated
# the conda commands/conda api are only available in an activated conda env!

# use subprocess directly as conda is best used from the shell
# we can decide to use "pure python" if needed later (maybe for non-linux?)
#import conda.cli.python_api

import subprocess
import json
#import yaml # use ruamel.yaml instead of pyyaml
# note that we use ruamel_yaml below because of conda namespace problems!
from ruamel_yaml import YAML
from ruamel_yaml.scalarstring import SingleQuotedScalarString
from pprint import pprint
from datetime import datetime
from urllib import request
import requests
from pkg_resources import parse_version
import pathlib
import sys
import time
import shlex

# global variables! to define behaviors of conda search, conda install etc.

conda_search_common_string="conda search --json --override-channels -c defaults -c conda-forge"
conda_install_common_string="conda install -y --override-channels -c defaults -c conda-forge"

def conda_list():
    proc = subprocess.run(["conda", "list", "--json", "--name"],
               text=True, capture_output=True)
    return json.loads(proc.stdout)


def conda_search(channel, name):

    # if channel is None, then use the fallback channels: defaults and conda-forge
    if(channel == None):

        proc = subprocess.run(shlex.split(conda_search_common_string) + name,
                text=True, capture_output=True)

    else:

        proc = subprocess.run(shlex.split(conda_search_common_string) + ["-c", channel,name],
                text=True, capture_output=True)

    return json.loads(proc.stdout)

def conda_install(package):
    proc = subprocess.run(["conda", "install", "--quiet", package],
               text=True, capture_output=True)
    return json.loads(proc.stdout)

def pip_install(package):
    proc = subprocess.run(["pip", "install", package],
               text=True, capture_output=True)
    return json.loads(proc.stdout)

def conda_get_latest_package(channel, name):

    # get the list of packages in the specified channel and with specified name
    package_list_json = conda_search(channel=channel, name=name)

    # get the creation timestamp of each package in the list, as a list of timestamps
    # we see a problem here, timestamp is missing in some cases ('make' for example)
    # add fallback (https://stackoverflow.com/a/44137340), we will ignore package that
    # does not have a timestamp entry
    timestamps_list = [package_json["timestamp"] for package_json in package_list_json[name] if "timestamp" in package_json]

    # sort the timestamp list (ascending)
    timestamps_list.sort()

    # we want the latest timestamp available, so get the last entry
    latest_timestamp = timestamps_list[-1]

    # conda package timestamps are in milliseconds, convert it into seconds (epoch)
    latest_timestamp_sec = latest_timestamp/1000
    # convert the epoch into a formatted datetime string for reference
    latest_timestamp_string = datetime.utcfromtimestamp(latest_timestamp_sec).strftime('%e %B %Y %H:%M:%S %Z')
    #print("latest timestamp:", latest_timestamp_sec)
    #print("in UTC          :", latest_timestamp_string)

    # get the package which has the latest timestamp
    for package_json in package_list_json[name]:
    
        if "timestamp" not in package_json:
            # ignore packages that do not have a timestamp field in the json!
            continue

        if(latest_timestamp == package_json["timestamp"]):

            print()
            print("-------------------")
            print(package_json["name"])
            print(package_json["channel"])
            print(package_json["version"])
            print(package_json["build"])
            print(datetime.utcfromtimestamp(package_json["timestamp"]/1000).strftime('%e %B %Y %H:%M:%S %Z'))
            print("-------------------")
            print()

            return package_json

def test__conda_get_latest_package():
    
    latest_package_json = conda_get_latest_package(channel="litex-hub/label/main",
                                                    name="yosys")

    latest_package_json = conda_get_latest_package(channel="litex-hub/label/main",
                                                    name="symbiflow-yosys-plugins")

    latest_package_json = conda_get_latest_package(channel="litex-hub/label/main",
                                                    name="vtr-optimized")

def pip_search(package):
    # use f-string: https://www.python.org/dev/peps/pep-0498/
    url = f'https://pypi.python.org/pypi/{package}/json'
    return json.loads(request.urlopen(url).read())['releases']

def pip_get_latest_package_version(package):

    package_releases_list_json = pip_search(package)
    package_releases_version_list_sorted = sorted(package_releases_list_json, key=parse_version, reverse=True)
    #pprint(package_releases_version_list_sorted)
    latest_version = package_releases_version_list_sorted[0]
    # releases may have multiple entries for each type (wheel/source/per-platform)etc.
    # so we cannot just take the first entry, it should match:
    # if wheel, then linux, or none, or ...
    # if source then anything is ok, wheel is built on local platform by pip.
    # so, ignore this for now, we do not need this information anyway, latest version is enough
    #latest_package_json = package_releases_list_json[latest_version][0]
    #pprint(latest_package_json)

    print()
    print("-------------------")
    print(package)
    print(latest_version)
    print("-------------------")
    print()

    return latest_version

def test__pip_get_latest_package_version():

    latest_version = pip_get_latest_package_version("serial")
    pprint(latest_version)
    latest_version = pip_get_latest_package_version("python-constraint")
    pprint(latest_version)
    latest_version = pip_get_latest_package_version("pyyaml")
    pprint(latest_version)

def git_get_latest_commits(repo, branch, num_commits):

    proc = subprocess.run(["./git_get_commit_list.sh", repo, branch, str(num_commits)],
               text=True, capture_output=True)

    #pprint(proc.stdout)
    return json.loads(proc.stdout)

def git_get_latest_commit(repo, branch):

    # get the commit history, limit to last 1 commit from the git repo
    commits_json = git_get_latest_commits(repo, branch, 1)
    # extract the first entry and return that
    latest_commit_sha1 = commits_json["commits"][0]

    print()
    print("-------------------")
    print(repo)
    print(branch)
    print(latest_commit_sha1)
    print("-------------------")
    print()

    return latest_commit_sha1

def test__git_get_latest_commits():

    commits_json = git_get_latest_commits("https://github.com/QuickLogic-Corp/symbiflow-arch-defs",
                                                            "master",
                                                            10)

    pprint(commits_json)

def test__git_get_latest_commit():

    latest_commit_sha1 = git_get_latest_commit("https://github.com/QuickLogic-Corp/symbiflow-arch-defs",
                                                            "master")

    latest_commit_sha1 = git_get_latest_commit("https://github.com/QuickLogic-Corp/symbiflow-arch-defs",
                                                            "quicklogic-upstream-rebase")

    latest_commit_sha1 = git_get_latest_commit("https://github.com/QuickLogic-Corp/ql_fasm",
                                                            "master")

    latest_commit_sha1 = git_get_latest_commit("https://github.com/QuickLogic-Corp/quicklogic-fasm",
                                                            "master")


def arch_defs_package_get_latest_version(repo, branch):

    latest_commit_sha1 = None

    commits_json = git_get_latest_commits(repo,
                                          branch,
                                          10)

    for commit_sha1 in commits_json["commits"]:

        commit_sha1_short = commit_sha1[:7]
        # print()
        # print(commit_sha1)
        # print(commit_sha1_short)

        arch_defs_tarball_url = f"https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-{commit_sha1_short}.tar.gz"

        http_response = requests.head(arch_defs_tarball_url, timeout=5)
        # pprint(http_response.headers)

        tarball_url_status_code = http_response.status_code
        tarball_url_content_type = http_response.headers.get("content-type")
        tarball_url_content_length = http_response.headers.get("content-length")
        # print(tarball_url_status_code)
        # print(tarball_url_content_type)
        # print(tarball_url_content_length)
        # print()

        if(tarball_url_status_code == 200 and 
            tarball_url_content_type == "application/x-tar"):

            latest_commit_sha1 = commit_sha1

            break

    print()
    print("-------------------")
    print(repo)
    print(branch)
    print(latest_commit_sha1)
    print("-------------------")
    print()   

    return latest_commit_sha1

def test__arch_defs_package_get_latest_version():

    arch_defs_package_get_latest_version("https://github.com/QuickLogic-Corp/symbiflow-arch-defs", "master")

    arch_defs_package_get_latest_version("https://github.com/QuickLogic-Corp/symbiflow-arch-defs", "quicklogic-upstream-rebase")



# main functions
# 1. check package spec and version updates, create package update spec
# 2. use the package update spec, compare to package current spec and generate installer script


def process_package_spec(installer_package_spec_yaml_file):

    yaml = YAML()
    yaml.preserve_quotes = True

    with open(installer_package_spec_yaml_file, "r") as stream:
        
        # pyyaml - replaced with ruamel.yaml
        # try:
        #     installer_package_spec_yaml = yaml.safe_load(stream)
        
        # except yaml.YAMLError as exc:
        #     print(exc)
        #     exit(1)

        installer_package_spec_yaml = yaml.load(stream)

    #pprint(installer_package_spec_yaml)

    for package_spec_yaml in installer_package_spec_yaml["package_list"]:

        # check for specific latest version of package only if:
        # 1. we have a specific "working-version" (not null)
        # AND
        # 2. the package is marked to be updated "update-to-latest" (is true)

        if(package_spec_yaml["working-version"] == None):
            # we don't care whether we update this package or not

            print()
            print("-------------------")
            print(package_spec_yaml["name"], "[SKIPPED]")
            print("we don't care if the version will change on update")
            print("-------------------")
            print()

            continue

        if(package_spec_yaml["update-to-latest"] == False):
            # this package should not be updated to latest version

            print()
            print("-------------------")
            print(package_spec_yaml["name"], "[SKIPPED]")
            print("this package should not be updated")
            print("-------------------")
            print()

            continue

        

        if(package_spec_yaml["type"] == "conda"):

            latest_package_json = conda_get_latest_package(channel=package_spec_yaml["channel"],
                                                    name=package_spec_yaml["name"])

            latest_version = latest_package_json["version"]            
            package_spec_yaml["latest-version"] = SingleQuotedScalarString(latest_version)

        elif(package_spec_yaml["type"] == "pip"):

            latest_version = pip_get_latest_package_version(package_spec_yaml["name"])
            package_spec_yaml["latest-version"] = SingleQuotedScalarString(latest_version)

        elif(package_spec_yaml["type"] == "gh"):

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


            if(package_spec_yaml["subtype"] == "pip"):

                latest_commit_sha1 = git_get_latest_commit(package_spec_yaml["repo"],
                                                            package_spec_yaml["branch"])
                package_spec_yaml["latest-version"] = SingleQuotedScalarString(latest_commit_sha1)

            elif(package_spec_yaml["subtype"] == "arch-defs"):

                latest_commit_sha1 = arch_defs_package_get_latest_version(package_spec_yaml["repo"],
                                                            package_spec_yaml["branch"])
                package_spec_yaml["latest-version"] = SingleQuotedScalarString(latest_commit_sha1)

            else:

                print("ERROR: Unknown subtype!")
                print()
                pprint(package_spec_yaml)

        else:

            print("unknown package type in spec!")
            pprint(package_spec_yaml)

    with open("installer_package_updates.yaml", "w") as stream:
        
        # pyyaml - replaced with ruamel.yaml
        # try:
        #     yaml.dump(installer_package_spec_yaml, stream, sort_keys=False)
        
        # except yaml.YAMLError as exc:
        #     print(exc)
        #     exit(1)

        yaml.dump(installer_package_spec_yaml, stream)


def create_installer_package(install_command_strings):

    # use the template, create a new installer package with the list of 
    # package install commands generated by process_package_updates


    with open("symbiflow_package_installer_template.sh", "r") as istream:

        with open("symbiflow_package_installer_updates.sh", "w") as ostream:

            for line in istream:

                if(line.__contains__("!!INGEN TEMPLATE PLACEHOLDER!!")):

                    # insert the set of commands here.
                    for command_string in install_command_strings:
                        ostream.write(command_string + "\n")

                else:

                    ostream.write(line)

    # done creating new installer script.



def process_package_updates(installer_package_updates_yaml_file):
    pass

    # compare the updates yaml to the current yaml
    # if current yaml does not exist, this is the first time we are running, proceed
    # if updates yaml has differences in "latest-version" fields AND update-to-latest is true, proceed
    #
    # if update-to-latest == false, install working version specifically
    # if update-to-latest == true
    #       if "latest-version" == null, then we don't care for a specific version, install
    #       else, we need a specific version, install the latest-version only.
    
    # check if current_yaml exists?

    yaml = YAML()
    yaml.preserve_quotes = True

    with open(installer_package_updates_yaml_file, "r") as stream:
        
        # pyyaml - replaced with ruamel.yaml
        # try:
        #     installer_package_spec_yaml = yaml.safe_load(stream)
        
        # except yaml.YAMLError as exc:
        #     print(exc)
        #     exit(1)

        installer_package_updates_yaml = yaml.load(stream)

    updated_installer_required = False

    if(pathlib.Path("installer_package_current.yaml").is_file()):

        pass
        # if versions differ, then updated installer required. TODO.

    else:

        updated_installer_required = True



    if(updated_installer_required):

        install_command_strings = []

        for package_spec_yaml in installer_package_updates_yaml["package_list"]:

            install_working_version = False
            install_latest_version = False
            install_any_version = False

            if(package_spec_yaml["update-to-latest"] == False):
                # this package should not be updated to latest version
                # use the working-version to be installed!

                install_working_version = True

            else: # need to update-to-latest

                if("latest-version" in package_spec_yaml):

                    install_latest_version = True

                else: # "latest-version" is NOT specified

                    install_any_version = True


            # according to the version to bne installed, generate the installation commands

            if(package_spec_yaml["type"] == "conda"):

                if(install_working_version):

                    install_command_strings.append('{conda_install} -c {channel} {name}="{version}"'.format(conda_install=conda_install_common_string,
                                                                                                            channel=package_spec_yaml["channel"],
                                                                                                            name=package_spec_yaml["name"],
                                                                                                            version=package_spec_yaml["working-version"]))

                elif(install_latest_version):

                    install_command_strings.append('{conda_install} -c {channel} {name}="{version}"'.format(conda_install=conda_install_common_string,
                                                                                                            channel=package_spec_yaml["channel"],
                                                                                                            name=package_spec_yaml["name"],
                                                                                                            version=package_spec_yaml["latest-version"]))

                elif(install_any_version):

                    install_command_strings.append('{conda_install} -c {channel} {name}'.format(conda_install=conda_install_common_string,
                                                                                                            channel=package_spec_yaml["channel"],
                                                                                                            name=package_spec_yaml["name"]))

            elif(package_spec_yaml["type"] == "pip"):
                
                if(install_working_version):

                    install_command_strings.append(f'pip install {package_spec_yaml["name"]}="{package_spec_yaml["working-version"]}"')

                elif(install_latest_version):

                    install_command_strings.append(f'pip install{package_spec_yaml["name"]}="{package_spec_yaml["latest-version"]}"')

                elif(install_any_version):

                    install_command_strings.append(f'pip install {package_spec_yaml["name"]}')


            elif(package_spec_yaml["type"] == "gh"):

                if(package_spec_yaml["subtype"] == "pip"):
                    
                    if(install_working_version):

                        install_command_strings.append(f'pip install git+{package_spec_yaml["repo"]}@{package_spec_yaml["working-version"]}')

                    elif(install_latest_version):

                        install_command_strings.append(f'pip install git+{package_spec_yaml["repo"]}@{package_spec_yaml["latest-version"]}')

                    elif(install_any_version):

                        install_command_strings.append(f'pip install git+{package_spec_yaml["repo"]}@{package_spec_yaml["branch"]}')


                elif(package_spec_yaml["subtype"] == "arch-defs"):

                    if(install_working_version):

                        commit_sha1 = package_spec_yaml["working-version"]

                    elif(install_latest_version):

                        commit_sha1 = package_spec_yaml["latest-version"]

                    elif(install_any_version):

                        print("ERROR! arch-defs should be installed with a specific version only!!!")
                        continue

                    commit_sha1_short = commit_sha1[:7]
                    tarball_url = f'https://storage.googleapis.com/symbiflow-arch-defs-install/quicklogic-arch-defs-qlf-{commit_sha1_short}.tar.gz'

                    install_command_strings.append("echo \"download and extract arch-defs tarball ...\"")
                    install_command_strings.append(f'curl -s {tarball_url} --output arch.tar.gz')
                    install_command_strings.append(f'tar -C $INSTALL_DIR -xvf arch.tar.gz && rm arch.tar.gz')


                else:

                    print("ERROR: Unknown package subtype!")
                    pprint(package_spec_yaml)

            else:

                print("ERROR: Unknown package type!")
                pprint(package_spec_yaml)

            # for each package loop end

        print()
        for command in install_command_strings:
            print(command)
        print()

        return install_command_strings


def display_logo():

    with open("asciilogo2.txt", "r") as stream:
        
        print()
        for line in stream:
            print(line, end="")
            time.sleep(0.05)
        print

    print()
    print("Symbiflow In(staller) Gen(erator)")
    print("version 0.1 (beta)")
    print()

    time.sleep(1)


if (__name__ == "__main__"):

    display_logo()
    #exit(0)

    #tests section
    #test__conda_get_latest_package()
    #test__pip_get_latest_package_version
    #test__git_get_latest_commits()
    #test__git_get_latest_commit()
    #test__arch_defs_package_get_latest_version()
    #exit(0)


    # [1] process spec
    # input = spec YAML, output = updates YAML
    # process "spec" YAML -> create "updates" YAML (check for new updates in conda/pip/gh...)
    #
    # [2] process updates
    # input = updates YAML, output = True/False + COMMANDS (create new installer)
    # check "updates" vs "current" (if "current" exists)
    # any version changes (or no "current") -> create new installer
    #
    # [3] create installer, test run
    # input = COMMANDS?, output = True/False (installation, test results generate csv)
    # run installer in new location, check basic test
    #
    # [4] installer CI
    # input = installer location, output = True/False (test results, generate csv)
    # run CI with new package
    #
    # [5] update installer status
    # input = installation result, basic test result, CI result
    # output = ?
    # OK ? installer marked green, saved to some location
    # NOT OK ? installer marked red, removed. save spec as "last_failed" ?
    # update CI test results in csv
    # update installer history in csv
    # convert csv to md -> github upload?


    # installer_package_updates_yaml = process_package_spec("installer_package_spec.yaml")
    # should_create_new_installer = process_package_updates(installer_package_updates_yaml)
    # create_installer_ok = create_installer_package(installer_package_updates_yaml, installer_package_working_dir)
    # installation_ok = 
    # CI_tests_ok =
    # publish_installer ... done.
    process_package_spec("installer_package_spec.yaml")
    generated_command_stringlist = process_package_updates("installer_package_updates.yaml")
    create_installer_package(generated_command_stringlist)








