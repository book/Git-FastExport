#!/bin/bash

# This script will pull all source repos every 300 seconds, and rebuild
# and push the resulting repo if there were any changes retrieved.
# Also, the master branch of the resulting repo is set to be the most
# recent branch of all the repository branches. Then, all non-master
# branches are deleted.

# "root" is a special repository which is unmarked. Its files go to the
# root of the combined repository. It can be configured as a local
# repository (so it is not pulled). However, the script needs to be
# re-run if the root repository is only locally updated.

SOURCE_REPOS="repo1 repo2 root:"
TARGET_REPO="repo_combined"

# Whether to pull the root repository.
PULL_ROOT=false

function update_repo() {
  SOURCE=$(echo $1 | sed -E 's/:.*//')
  cd $SOURCE
  FIRST_RUN=$2
  
  if [[ $FIRST_RUN = "true" ]]; then echo "First run: $FIRST_RUN."; fi
 
  OLD_HEAD=$(git rev-parse master)
  #git remote update | grep -v "Fetching origin"
  if [[ "$SOURCE" != "root" || "$PULL_ROOT" = "true" ]]; then
    git pull origin master 2>&1 | grep -v -E "^From" | grep -v "FETCH_HEAD" | grep -v "Already up-to-date."
  fi
  NEW_HEAD=$(git rev-parse master)
  cd ..
  if [[ "$OLD_HEAD" != "$NEW_HEAD" || $FIRST_RUN = "true" ]]; then
    if [[ "$OLD_HEAD" != "$NEW_HEAD" ]]; then
      echo "Updated $SOURCE!"
      echo "Old head: $OLD_HEAD"
      echo "New head: $NEW_HEAD"
    fi
    cd "$TARGET_REPO"
    (cd ..; git-stitch-repo $SOURCE_REPOS) | git fast-import --force --quiet
    git update-ref -d refs/heads/master
    BRANCHES_SORTED=$(git branch --sort=-committerdate | sed -E "s/[ *]+//g")
    NEWEST_BRANCH=$(echo "$BRANCHES_SORTED" | head -n 1)
    echo "Newest branch is $NEWEST_BRANCH"
    ALL_BRANCHES=$(echo "$BRANCHES_SORTED" | tr '\n' ' ')
    git update-ref refs/heads/master $NEWEST_BRANCH
    git branch -D $ALL_BRANCHES
    git push origin --force
    cd ..
  fi
}

 # First run, always stitches & pushes.
 update_repo $(echo "$SOURCE_REPOS" | cut -f1 -d' ') true

while true; do
  date
  for repo in $SOURCE_REPOS; do
    update_repo $repo false
  done
  sleep 300
done
