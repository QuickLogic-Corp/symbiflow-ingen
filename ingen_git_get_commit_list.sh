#!/bin/bash


# utility script to get commit history of any git repo + branch
# prerequisites: git,jq

# usage:
# ingen_git_get_commit_list.sh <repo> <branch> <num-commits>

# arguments:
# $1 = repo
# $2 = branch
# $3 = number of last 'N' commits needed
# output:
# commit history as json - can be processed by clients programmatically
# the "commits" JSON array has each commit with the latest (HEAD) first and older ones in sequence
# {
#     "commits": [
#         {
#             "sha1":"commit_sha1",
#             "sha1_short":"commit_sha1_short",
#             "log":"commit_sha1_oneline_log"
#         },
#         ... repeat
#         {
#             "sha1":"commit_sha1",
#             "sha1_short":"commit_sha1_short",
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


# -n is null-input, so no json to input, starts from scratch
# -r is raw-output, filter's result string has no quotes added in output
# add an empty JSON array with key="commits"
COMMITS_LIST_JSON=$(jq -n -r '. += {"commits": []}')
while [ $COMMIT_i -lt $NUM_FALLBACK_COMMITS ]
do

    #echo
    #echo
    #echo $COMMIT_i

    # the CI workflow generated .tar.gz uses first 7 characters for SHA1 - this is git default (for "normal" sized repo history)
    # however, as the repo grows, this can be higher, it is 8 right now for our repo.
    # revisit this and sync with the workflow to use 8 or higher to prevent possible collisions?
    # need to check how the CI workflow with $(git rev-parse --short HEAD) is getting len=7 but we get len=8?
    SHA1_SHORT=$(git rev-parse --short=7 HEAD~$COMMIT_i)
    SHA1=$(git rev-parse HEAD~$COMMIT_i)
    #echo "$SHA1"
    #echo "$SHA1_SHORT"

    # use pretty formats to get exactly what we want
    # https://git-scm.com/docs/pretty-formats#Documentation/pretty-formats.txt-emHem
    # https://www.edureka.co/blog/git-format-commit-history/
    LOG=$(git log --pretty=format:"%cs %s" HEAD~$COMMIT_i -1)
    #echo "$LOG"

    # add a JSON object for the commit with {"sha1": $SHA1, "log": $LOG} into the "commits:[]" array at the root of the JSON document:
    # use --arg to make it easy, remember that jq environment is separate, and this makes it easy to "pass in" bash variables or values 
    # into jq
    COMMITS_LIST_JSON=$(echo "$COMMITS_LIST_JSON" | jq -r --arg argSHA1 "$SHA1" --arg argSHA1_SHORT "$SHA1_SHORT" --arg argLOG "$LOG" '.commits += [{"sha1" : $argSHA1, "sha1-short": $argSHA1_SHORT, "log" : $argLOG}]')
    #echo "$COMMITS_LIST_JSON" | jq '.'

    COMMIT_i=$((COMMIT_i+1))

done

#echo "$COMMITS_LIST_JSON" | jq '.'

# cleanup temporary directory
cd "$GIT_CHECKER_CURRENT_DIR"
rm -rf "$GIT_CHECKER_TEMP_DIR"

echo $COMMITS_LIST_JSON | jq '.' -c
#echo "$COMMITS_LIST_JSON"
