#!/bin/bash


# utility script to get commit history of any git repo + branch
# prerequisites: git,jq

# usage:
# git_get_commit_list.sh <repo> <branch> <num-commits>

# arguments:
# $1 = repo
# $2 = branch
# $3 = number of last 'N' commits needed
# output:
# commit history as json - can be processed by clients programmatically
# {"commits":[sha1,sha1,sha1...]}

#
# TODO remove hacky ways to add bash variables into jq '' and use --arg!
# TODO: add the git log for each commit sha1 in the future...
# {
#     "commits": [
#         {
#             "sha1":"commit_sha1",
#             "log":"commit_sha1_oneline_log"
#         },
#         ... repeat
#         {
#             "sha1":"commit_sha1",
#             "log":"commit_sha1_oneline_log"
#         },
#     ]
# }


#echo $#
if [ "$#" -ne 3 ] ; then

    echo "usage: $0 <repo-url> <branch> <num-commits>" >&2
    exit 1
fi


GIT_CHECKER_REPO="$1"
GIT_CHECKER_BANCH="$2"
GIT_CHECKER_NUM_COMMITS="$3"
GIT_CHECKER_TEMP_DIR="bare_git_repo_dir_temp"

GIT_CHECKER_CURRENT_DIR=`pwd`
# get latest commit SHA1 on specified repo/branch

NUM_FALLBACK_COMMITS="$GIT_CHECKER_NUM_COMMITS"
COMMIT_i=0

# bare clone into a temporary directory
git clone --quiet --bare "$GIT_CHECKER_REPO" -b "$GIT_CHECKER_BANCH" "$GIT_CHECKER_TEMP_DIR" 2>&1 > /dev/null
cd "$GIT_CHECKER_TEMP_DIR"

COMMITS_COUNT=$(git rev-list --count HEAD)
#echo $COMMITS_COUNT

# ensure we have only max number of fallback commits upto number of actual commits in the branch
if [ $COMMITS_COUNT -lt  $NUM_FALLBACK_COMMITS ] ; then

    NUM_FALLBACK_COMMITS=$COMMITS_COUNT

fi
#echo $NUM_FALLBACK_COMMITS

COMMITS_LIST=()
COMMIT_LOG_LIST=()

while [ $COMMIT_i -lt $NUM_FALLBACK_COMMITS ]
do

    #echo $COMMIT_i

    # the workflow generated .tar.gz uses first 7 characters for SHA1 - this is git default (for "normal" sized repo history)
    # however, as the repo grows, this can be higher, it is 8 right now for our repo.
    # revisit this and sync with the workflow to use 8 or higher to prevent possible collisions.
    #SHA1=$(git rev-parse HEAD~$COMMIT_i | cut -c1-7)
    SHA1=$(git rev-parse HEAD~$COMMIT_i)
    #echo $SHA1

    LOG=$(git log --pretty=format:%s HEAD~$COMMIT_i -1)
    #echo $LOG

    COMMITS_LIST+=("$SHA1")
    COMMIT_LOG_LIST+=("$LOG")

    COMMIT_i=$((COMMIT_i+1))

done

#echo "${COMMITS_LIST[*]}"
#echo "${COMMIT_LOG_LIST[*]}" # not used yet


# create a json object, add an array object inside it.
#COMMITS_LIST_JSON=$(echo "{}" | jq '. += {"commits": []}')
COMMITS_LIST_JSON=$(jq -n -r '. += {"commits": []}')

for COMMIT_SHA1 in ${COMMITS_LIST[*]}
do

    # note the extra double-quotes in \""$COMMIT_SHA1"\" - this is required because
    # the SHA1 is interpreted as a value, and jq groans, ensure it gets treated as a string!
    COMMITS_LIST_JSON=$(echo "$COMMITS_LIST_JSON" | jq -r '.commits += ['\""$COMMIT_SHA1"\"']')
    #echo $COMMIT_SHA1

done

# cleanup temporary directory
cd "$GIT_CHECKER_CURRENT_DIR"
rm -rf "$GIT_CHECKER_TEMP_DIR"

#echo $COMMITS_LIST_JSON | jq '.'
echo $COMMITS_LIST_JSON
