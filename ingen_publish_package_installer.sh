#!/bin/bash


##########################################################################################
# parse args
##########################################################################################
# gha mode: if enabled, create PR and wait for gh actions to publish release
# if not specified, then we are in standalone mode, and this script will
# also merge PR and publish release without triggering gh actions.
GHA_MODE="github-actions"
GHA_MODE_ENABLED="$FALSE_VAL"

if [ $# == 1 ] ; then

    if [ "$1" == "$GHA_MODE" ] ; then

        echo ""
        echo "[>> INGEN <<] GHA MODE specified!"
        echo ""

        GHA_MODE_ENABLED="$TRUE_VAL"

    fi

fi
##########################################################################################


##########################################################################################
# EXPORTED VARIABLES: use the variables exported from parent script : ingen_kickoff.sh
##########################################################################################
# root repo dir
INGEN_ROOT_DIR="$INGEN_ROOT_DIR"

# name of the Symbiflow Package Installer
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME="$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME"

# path to the package installer to publish
INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH="$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH"

# date
CURRENT_DATE="$CURRENT_DATE"
##########################################################################################


# publish a 'release' to gh:
# 1. create a new 'release' branch called releases/$DATE
# 2. add the installer to staging
# 3. commit the changes to the branch
# 4. push the branch upstream to origin
# 5. create a PR from 'release' branch to master

## GH ACTIONS STARTS HERE ##
    # 6. approve the PR automatically (optional)
    # 7. merge the PR to master
    # 8. create a new release with the latest master
## GH ACTIONS FINISHES HERE

# 9. wait for the new release to be created...
# 10. done.


##########################################################################################
# STEP 1 : commit the installer into a new releases branch
##########################################################################################
echo
echo "[>> INGEN <<] commit final package installer to gh..."
echo

if [ "$GHA_MODE_ENABLED" == "$TRUE_VAL" ] ; then
    RELEASE_BRANCH_NAME="releases/${CURRENT_DATE}"
else
    # use a different name for the releases branch to prevent triggering gh actions
    RELEASE_BRANCH_NAME="releases-no-gha/${CURRENT_DATE}"
fi
DEFAULT_BRANCH_NAME="master"

git checkout -b "$RELEASE_BRANCH_NAME"
# add the installer package to commit
git add "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH"
# add the 'updated' package current yaml corresponding to the new installer package to commit
git add "$INGEN_PACKAGE_CURRENT_YAML"
git commit -m "[INGEN] publish installer for $CURRENT_DATE"
git push -u origin "$RELEASE_BRANCH_NAME"

COMMIT_PUSH_STATUS=$?

if [ $COMMIT_PUSH_STATUS -ne 0 ] ; then
    echo
    echo "[>> INGEN <<] ERROR: could not push installer to new branch on remote."
    echo "aborting."
    echo
    exit 1
fi
##########################################################################################



##########################################################################################
# STEP 2 : obtain the PAT from the local git config
##########################################################################################
# assuming we cloned the repo using a PAT, the token is stored in .git/config file in plaintext
# what we want is the pattern: "url = https://TOKEN@github.com/OWNER/REPO[.git]"
# using regex:
regex_git_info_string="^.*url.*=.*https://(.+)@github.com/([^/]+)/(\S+)(\..*|\s+)"
git_info_string=`cat .git/config`

if [[ $git_info_string =~ $regex_git_info_string ]] ; then
    #echo "${BASH_REMATCH[1]}" # token
    #echo "${BASH_REMATCH[2]}" # username
    #echo "${BASH_REMATCH[3]}" # repo or repo.git

    GH_CONFIG_TOKEN=${BASH_REMATCH[1]}  # use the token from here
    GH_CONFIG_OWNER=${BASH_REMATCH[2]}  # we don't use this
    GH_CONFIG_REPO=${BASH_REMATCH[3]}   # we don't use this
fi

if [ -z "$GH_CONFIG_TOKEN" ] ; then
    echo
    echo "[>> INGEN <<] ERROR: could not obtain PAT from local .git/config..."
    echo "did you clone the repo using a PAT?"
    echo "aborting."
    echo
    exit 1
fi
##########################################################################################



##########################################################################################
# STEP 3 : obtain gh-cli and add to path
##########################################################################################
GH_CLI_VERSION="2.4.0"
GH_CLI_LINUX_BIN_NAME="gh_${GH_CLI_VERSION}_linux_amd64"
if [ ! -d "$GH_CLI_LINUX_BIN_NAME" ] ; then

    if [ ! -f "${GH_CLI_LINUX_BIN_NAME}.tar.gz" ] ; then

        wget "https://github.com/cli/cli/releases/download/v${GH_CLI_VERSION}/${GH_CLI_LINUX_BIN_NAME}.tar.gz"

    fi

    tar -xf "${GH_CLI_LINUX_BIN_NAME}.tar.gz"

fi


# add to path:
GH_CLI_BIN_DIR_PATH="${PWD}/${GH_CLI_LINUX_BIN_NAME}/bin"
export PATH="${GH_CLI_BIN_DIR_PATH}:${PATH}"


# test gh-cli:
TEST_GH_BIN_PATH=$(which gh)

if [ "$TEST_GH_BIN_PATH" != "${GH_CLI_BIN_DIR_PATH}/gh" ] ; then

    echo
    echo "[>> INGEN <<] ERROR: unexpected gh cli bin in path!"
    echo "expected: $GH_CLI_BIN_DIR_PATH"
    echo "     got: $TEST_GH_BIN_PATH"
    echo
    exit 1

fi

# print gh-cli version:
echo
gh --version
echo
##########################################################################################



##########################################################################################
# STEP 4 : authorize gh-cli with the PAT
##########################################################################################
echo "$GH_CONFIG_TOKEN" | gh auth login --with-token
GH_LOGIN_STATUS=$?

if [ $GH_LOGIN_STATUS -ne 0 ] ; then

    echo
    echo "[>> INGEN <<] ERROR: gh cli login using token failed: $GH_LOGIN_STATUS"
    echo
    exit 1

fi

echo
echo "[>> INGEN <<] gh cli login [OK]"
echo
##########################################################################################



##########################################################################################
# STEP 5 : create PR to merge installer to default branch
##########################################################################################
# create PR
PR_TITLE="[INGEN] add new release: ${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME}"
PR_BODY="[INGEN] auto created PR for adding a new release."
PR_HEAD="$RELEASE_BRANCH_NAME"
PR_BASE="$DEFAULT_BRANCH_NAME"
PR_URL=$(gh pr create --title "$PR_TITLE" \
             --body "$PR_BODY" \
             --head "$PR_HEAD" \
             --base "$PR_BASE" \
             )

GH_PR_CREATE_STATUS=$?

if [ $GH_PR_CREATE_STATUS -ne 0 ] ; then

    echo
    echo "[>> INGEN <<] ERROR: gh pr create failed: $GH_PR_CREATE_STATUS"
    echo
    exit 1

fi

echo
echo "[>> INGEN <<] gh pr created [OK]"
echo "    $PR_URL"
echo
##########################################################################################



##########################################################################################
# STEP 6 : check if in standalone mode: merge PR, publish release
##########################################################################################
if [ ! "$GHA_MODE_ENABLED" == "$TRUE_VAL" ] ; then


    # approve PR (optional) - need PAT of user other than the PAT used for creating PR!
    # (not used in script flow!)



    ##########################################################################################
    # STEP 6a : merge PR (squash and merge as a single commit)
    ##########################################################################################
    PR_MERGE_BODY="[INGEN] auto merge PR for release"
    PR_MERGE_RESPONSE=$(gh pr merge $PR_URL --auto --delete-branch --squash --body "$PR_MERGE_BODY")

    GH_PR_MERGE_STATUS=$?

    if [ $GH_PR_MERGE_STATUS -ne 0 ] ; then

        echo
        echo "[>> INGEN <<] ERROR: gh pr merge failed: $GH_PR_MERGE_STATUS"
        echo "$GH_PR_MERGE_STATUS"
        echo
        exit 1

    fi

    echo
    echo "[>> INGEN <<] gh merge [OK]"
    echo



    ##########################################################################################
    # STEP 6b : pull in latest remote and switch to default branch now
    ##########################################################################################
    git checkout "$DEFAULT_BRANCH_NAME"
    git pull



    ##########################################################################################
    # STEP 6c : identify new tag version to use (semver)
    ##########################################################################################
    CURRENT_VERSION=`git describe --abbrev=0 --tags 2>/dev/null || true`
    if [ -z $CURRENT_VERSION ] ; then
        
        CURRENT_VERSION="v0.0.0"
        NEW_VERSION="v2.2.0"

    else

        # remove "v"
        CURRENT_VERSION_PARTS=$(echo "$CURRENT_VERSION" | sed 's/v//')
        # replace . with space so can split into an array
        CURRENT_VERSION_PARTS=(${CURRENT_VERSION_PARTS//./ })

        # get MAJOR, MINOR, PATCH
        V_MAJOR=${CURRENT_VERSION_PARTS[0]}
        V_MINOR=${CURRENT_VERSION_PARTS[1]}
        V_PATCH=${CURRENT_VERSION_PARTS[2]}

        # use custom logic to determine new MAJOR/MINOR/PATCH version numbers:
        # current we use a simple "increment minor"
        V_MINOR=$((V_MINOR+1))

        # remember to add "v"
        NEW_VERSION="v${V_MAJOR}.${V_MINOR}.${V_PATCH}"

    fi

    echo
    echo "[>> INGEN <<]"
    echo "CURRENT_VERSION=$CURRENT_VERSION"
    echo "NEW_VERSION=$NEW_VERSION"
    echo



    ##########################################################################################
    # STEP 6d : publish release
    ##########################################################################################
    RELEASE_NOTES_FILE="${INGEN_ROOT_DIR}/symbiflow_installer/package_changelog.txt"
    RELEASE_TITLE="${NEW_VERSION} : ${INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME}"
    GH_RELEASE_URL=$(gh release create --title "$RELEASE_TITLE" \
                                        --notes-file "$RELEASE_NOTES_FILE" \
                                        --target "$DEFAULT_BRANCH_NAME" \
                                        "$NEW_VERSION" \
                                        "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_PUBLISH_PATH" )

    GH_RELEASE_STATUS=$?


    if [ $GH_RELEASE_STATUS -ne 0 ] ; then

        echo
        echo "[>> INGEN <<] ERROR: gh release create failed: $GH_RELEASE_STATUS"
        echo "$GH_RELEASE_URL"
        echo
        exit 1

    fi

fi # if we are in standalone mode
##########################################################################################



##########################################################################################
# STEP 7 : wait for the release to be published
##########################################################################################
TIMEOUT=120
RETRY_TIME=30
CURR_TIME=0
RELEASE_ASSET=""

echo
echo "[>> INGEN <<] waiting for release to be published ..."

while [ $CURR_TIME -le $TIMEOUT ] ; do

    sleep $RETRY_TIME

    RELEASE_ASSET=$(gh release view --json assets --jq '.assets[].name')
    
    if [ "$RELEASE_ASSET" == "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME" ] ; then
        break
    fi

    CURR_TIME=$(($CURR_TIME + $RETRY_TIME))

    echo "[waiting]"

done

if [ "$RELEASE_ASSET" == "$INGEN_SYMBIFLOW_INSTALLER_ARCHIVE_NAME" ] ; then

    RELEASE_TAG=$(gh release view --json tagName --jq '.tagName')
    RELEASE_URL=$(gh release view --json url --jq '.url')
    RELEASE_ASSET_URL=$(gh release view --json assets --jq '.assets[].url')

    echo
    echo "[>> INGEN <<] release created by GHA [OK]"
    echo "        RELEASE_TAG: $RELEASE_TAG"
    echo "        RELEASE_URL: $RELEASE_URL"
    echo "      RELEASE_ASSET: $RELEASE_ASSET"
    echo "  RELEASE_ASSET_URL: $RELEASE_ASSET_URL"
    echo

else

    echo "[>> INGEN <<] ERROR: timed out waiting for new release creation!"
    echo "    check the GH Actions workflow/Script for any errors!"

fi
##########################################################################################



##########################################################################################
# STEP 8 :cleanup
##########################################################################################

# logout of gh-cli
echo "Y" | gh auth logout --hostname github.com


# checkout default branch and fetch new tags
git checkout "$DEFAULT_BRANCH_NAME"
git pull
git fetch --tags origin


# clean up branches
# remove pointers to remote branches that don't exist
git fetch --prune
# delete local branches which don't have remotes (merged only)
#git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -d
# force delete local branches without remotes (unmerged)
git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D


# exit
exit 0
##########################################################################################
