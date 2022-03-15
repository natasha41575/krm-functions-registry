#!/bin/bash
#
# Copyright 2022 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

if [ "$#" -lt 1 ]; then
    echo "function name required as parameter"
    exit 1
fi

FUNCTION_NAME=$1
RELEASE_TYPE=$2
if [ -z "$RELEASE_TYPE" ]
  then
    RELEASE_TYPE="patch"
fi

# todo: replace with krm-functions-registry
LAST_TAG=`curl -sL http://api.github.com/repos/GoogleContainerTools/kpt-functions-catalog/releases | jq ".[].tag_name" | grep $FUNCTION_NAME | head -n 1`

if [ -z "$LAST_TAG" ]; then
    # function has not been released yet. We want the first release to be 0.1.0, so we set RELEASE_TYPE to minor and LAST_TAG to 0.0.0
    echo "function has not been released yet, first release will be v0.1.0"
    LAST_TAG=$FUNCTION_NAME/v0.0.0
    RELEASE_TYPE="minor"
fi
echo $LAST_TAG

VERSION=$(echo $LAST_TAG | sed 's:.*v::' | tr -d '"')

if [ $RELEASE_TYPE == "patch" ]; then
  VERSION=v`echo $VERSION | awk -F. '{$3 = $3 + 1;} 1' | sed 's/ /./g'`
elif [ $RELEASE_TYPE == "minor" ]; then
  VERSION=v`echo $VERSION | awk -F. '{$2 = $2 + 1;} 1' | sed 's/ /./g'`
elif [ $RELEASE_TYPE == "major" ]; then
  VERSION=v`echo $VERSION | awk -F. '{$1 = $1 + 1;} 1' | sed 's/ /./g'`
else
  echo "invalid release type; must be 'patch', 'minor', or 'major'"
  exit 1
fi

echo $VERSION

nl=$'\n'
read -p "Preparing to release $FUNCTION_NAME/$VERSION. Continue? [Y] or [N]${nl}" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Triggering release..."
else
  echo "Stopped."
  exit 1
fi

# assure clean workspace
echo "assuring clean workspace..."
if ! (git status | grep -q 'nothing to commit, working tree clean'); then
  echo "please ensure a clean workspace and run again"
  exit 1
fi


# fetch remote
echo "fetching remote..."
git fetch origin

# checkout main branch
echo "checking out main..."
git checkout main

# merge from remote main
echo "rebasing from main..."
git rebase origin/main

# assure clean workspace
echo "assuring clean workspace..."
if ! (git status | grep -q 'nothing to commit, working tree clean'); then
  echo "please ensure a clean workspace and run again"
  exit 1
fi

# checkout release branch
echo "checking out release branch..."
git checkout $RELEASE_BRANCH

# merge from remote main
echo "rebasing from main..."
git rebase origin/main

# push branch to remote
echo "pushing release branch to remote..."
git push origin $RELEASE_BRANCH

# create local release tag
echo "creating local tag..."
git tag $FUNCTION_NAME/$VERSION

# push tag to remote
echo "pushing tag to remote..."
git push origin $FUNCTION_NAME/$VERSION

# checkout main branch
echo "checking out main..."
git checkout main

echo "release.sh: success."
