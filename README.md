# Symbiflow Package Installer Generator

## Notes

1. use `environment.yml` and `requirements.txt` for installing conda environments rather than 
   installing each package separately using `conda install <package>` because the env solver 
   can easily solve the dependency graph in one go.  
   Otherwise, we see issues such as not being able to resolve dependency later, or a step where 
   all the packages are switched between channels for compatibility (conda-forge and defaults for example)

2. use a conda environment and install the packages directly, rather than using `conda search`.  
   This will use the env solver and we get the right packages as we would get when we actually 
   execute the installer later, `conda search` depends on the search factors used, and we cannot 
   really specify all the factors easily.  
   Once the packages are installed, query their versions and build the installer.

## Workflow

1. `ingen_harness.sh` [1] &rarr; kicks off the process by installing a new conda env named 
   `ingen` with `python 3.7`.  
   The `ingen` env contains the necessary tools for the ingen workflow, such as `git`, 
   `pip`, `jq` and more.
   
2. `ingen_harness.sh` [2] &rarr; invokes `ingen_generate_conda_env_configuration.py` which uses the 
   `ingen_package_spec.yml` and produces `ingen_builder_environment.yml` and 
   `ingen_builder_requirements.txt` which will be used to create the new `ingen_builder` 
   conda env

3. `ingen_harness.sh` [3] &rarr; creates a new conda env using the `ingen_builder_environment.yml` 
   and `ingen_builder_requirements.txt`

4. `ingen_harness.sh` [4] &rarr; invokes `ingen_generate_package_updates.py` which uses the 
   `ingen_package_spec.yml` and helper scripts to generate `ingen_package_updates.yml`

   The helper scripts include:

   - `ingen_git_get_commit_list.sh` : this script clones `bare` git repo and gets the info for 
     the last specified number of commits from the HEAD
     
     TODO: document the shell script inputs and output format (json)

   - `conda_get_installed_package_info.sh` : this script can get the info of an *installed* 
     package from a specified conda env

     TODO: document the shell script inputs and output format (json)

   `NOTE` This will indicate whether a new installer package needs to be created (only if 
   there are updates in the packages)

5. `ingen_harness.sh` [5] &rarr; invokes `ingen_generate_conda_env_configuration.py` which uses the 
   `ingen_package_updates.yml` and produces `symbiflow_dailybuild/environment.yml` and 
   `symbiflow_dailybuild/requirements.txt` which will be used, in combination 
   with the `symbiflow_dailybuild_installer.sh` script to produce the final dailybuild 
   installer

6. `ingen_harness.sh` [6] &rarr; uses `makeself` and generates a dailybuild installer package 
   from `symbiflow_dailybuild/`

7. `ingen_harness.sh` [7] &rarr; invokes `ingen_test_installer.sh` with the generated 
   dailybuild installer, in a new bash shell

8. `ingen_test_installer.sh` [1] &rarr; invokes the dailybuild installer to install the 
   symbiflow packages

9. `ingen_test_installer.sh` [2] &rarr; configures the installation and runs the `sanity` tests

10. `ingen_harness.sh` [8] &rarr;  publishes the new package to `TODO_PATH`

11. `ingen_harness.sh` [9] &rarr; run CI using the new package (invoke separate test path ?)

`NOTE` CI path should be capable of collating test results and reporting it.
