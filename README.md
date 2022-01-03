# Symbiflow Package Installer Generator (INGEN)

This repo contains a set of scripts which automates the process of creating a symbiflow package installer, also called a symbiflow dailybuild.  

This is meant to be run periodically (nightly) on any machine - which will check for updates, create and sanity test a new package installer and then will publish it (if all ok) to github as a `release`.  

The release versions start at `v2.2.0` to avoid using any of the older versions which are already in use.  
Each release version corresponds to a specific date on which the package installer was published on github.  

## Developer Notes

1. use `environment.yml` and `requirements.txt` for installing conda environments rather than 
   installing each package separately using `conda install <package>` because the env solver 
   can easily solve the dependency graph in one go.  
   Otherwise, we see issues such as not being able to resolve dependency later, or a step where 
   all the packages are switched between channels for compatibility (conda-forge and defaults for example)

2. use a conda environment and install the packages directly, rather than using `conda search`.  
   This will use the env solver and we get the right packages as we would get when we actually 
   execute the installer later, `conda search` depends on the search factors used, and we cannot 
   really specify all the factors easily.  
   `conda search` was not meant to be a user spec driven tool, unfortunately.
   Once the packages are installed, query their versions and build the installer.

3. use an existing conda env and update it simply by using a newer `environment.yml` and `requirements.txt` 
   rather than deleting the conda env and recreating it with the newer files.


## Structure

├── `README.md` `this file`

├── ingen_kickoff.sh `main wrapper file`
├── ingen_generate_package_installer.sh `checks for updates and generates a package installer`
├── ingen_test_package_installer.sh `runs the package installer through sanity (k6n10, k4n8, eoss3, pp3)`
├── ingen_publish_package_installer.sh `publishes the package installer as a Github Release`

├── ingen_conda_helper.sh `helper bash script with conda commands wrapped`
├── ingen_git_get_commit_list.sh `helper bash script to get git repo info`

├── ingen_requirements.txt `conda (pip) requirements.txt spec for the INGEN env`
├── ingen_environment.yml `conda environment.yml spec for the INGEN env`

├── ingen_generate_package_updates.py `helper py script to generate updated dependencies`
├── ingen_check_for_updates.py `helper py script to analyze generated updated dependencies`
├── ingen_generate_conda_env_configuration.py `helper py script to generate a conda env for the package installer`
├── ingen_generate_installer_script.py `helper py script to generate installer script from a template`

├── ingen_package_spec.yml `base spec to describe every dependency of the package installer`
├── ingen_package_current.yml `current versions of every dependency in the base spec at the latest release`
├── ingen_installer_script_template.sh `template for final package installer script`

├── installers
    ├── dailybuild `all package installers are available here`
├── makeself-2.3.1.run `util to create the final self-extracting package installer`
└── tests `sanity tests for package installer`


## Workflow

A brief workflow is described, `TODO` add diagrams/details.

- [A] generate a new package installer
  - creates a new local conda installation
  - creates a new `ingen` conda env needed for running rest of the steps (git/jq...)
  - generates `requirements.txt` and `environment.yml` for `ingen_builder` conda env from the `ingen_package_spec.yml` base specification for the package installer
  - creates a new `ingen_builder` conda env from the above - this accurately reflects the structure of the 'potential' new package installer
  - extracts the current versions of every dependency in the `ingen_package_spec.yml` from the `ingen_builder` conda env into `ingen_package_updates.yml` which mirrors `ingen_package_spec.yml`, but with all versions updated
  - removes the `ingen_builder` conda env as it is no longer needed
  - checks for updates for every dependency between `ingen_package_updates.yml` and `ingen_package_current.yml` (which contains the versions of every dependency of the currently published package installer)
  - if there are no updates of interest, the process stops, else proceeds as below
  - creates a new self extracting package installer with the steps below:
    - using the `ingen_package_updates.yml`, generates a set of `requirements.txt` and `environment.yml` for the new package installer
    - generates a `symbiflow_installer.sh` script from the template `ingen_installer_script_template.sh`
    - copies the `conda_helper.sh`, `ingen_package_updates.yml` and `package_changelog.txt` as well
    - create self-extracting package installer using makeself-2.3.1
    - naming format is: `symbiflow_dailybuild_dd_MMM_YYYY.gz.run`  
  
- [B] sanity test the generated package installer with basic tests of k6n10, k4n8, eoss3, pp3
- [C] publish the generated package installer to Github Releases using the `gh-cli` + `github-actions`

## TODO

1. add complete CI flow automatically once the package installer is generated, tested and published
2. optimize out the conda install, env creation if it has already been initialized once (saves time/bandwidth)
3. document the `ingen_package_spec.yml` and `ingen_package_current.yml` formats (it is documented within already)
4. optimize the git repo info extraction by using `gh-cli` rather than plain git (faster)
