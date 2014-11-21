#!/bin/bash

if [ "$CI" == "true" ]; then
    echo "Skipping build number update script under CI."
    exit 0
fi

# Source: https://gist.github.com/karlvr/c93a98d7000ecb163895

# This script automatically sets the version and short version string of
# an Xcode project from the Git repository containing the project.
#
# To use this script in Xcode, add the script's path to a "Run Script" build
# phase for your application target.

set -o errexit
set -o nounset

# First, check for git in $PATH
hash git 2>/dev/null || { echo >&2 "Git required, not installed.  Aborting build number update script."; exit 0; }

# Alternatively, we could use Xcode's copy of the Git binary,
# but old Xcodes don't have this.
#GIT=$(xcrun -find git)

# Run Script build phases that operate on product files of the target that defines them should use the value of this build setting [TARGET_BUILD_DIR]. But Run Script build phases that operate on product files of other targets should use “BUILT_PRODUCTS_DIR” instead.
INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

# Build version (closest-tag-or-branch "-" commits-since-tag "-" short-hash dirty-flag)
BUILD_VERSION=$(git describe --tags --always --dirty=+)

# Use the latest tag for short version (expected tag format "vn[.n[.n]]")
# or if there are no tags, we make up version 0.0.<commit count>
LATEST_TAG=$(git describe --tags --match 'v*' --abbrev=0 2>/dev/null) || LATEST_TAG="HEAD"
if [ $LATEST_TAG = "HEAD" ]; then
    COMMIT_COUNT=$(git rev-list --count HEAD)
    LATEST_TAG="0.0.$COMMIT_COUNT"
    COMMIT_COUNT_SINCE_TAG=0
else
    COMMIT_COUNT_SINCE_TAG=$(git rev-list --count ${LATEST_TAG}..)
    LATEST_TAG=${LATEST_TAG##v} # Remove the "v" from the front of the tag
fi

if [ $COMMIT_COUNT_SINCE_TAG = 0 ]; then
    SHORT_VERSION="$LATEST_TAG"
else
    # increment final digit of tag and append "d" + commit-count-since-tag
    # e.g. commit after 1.0 is 1.1d1, commit after 1.0.0 is 1.0.1d1
    # this is the bit that requires /bin/bash
    OLD_IFS=$IFS
    IFS="."
    VERSION_PARTS=($LATEST_TAG)
    LAST_PART=$((${#VERSION_PARTS[@]}-1))
    VERSION_PARTS[$LAST_PART]=$((${VERSION_PARTS[${LAST_PART}]}+1))
    SHORT_VERSION="${VERSION_PARTS[*]}d${COMMIT_COUNT_SINCE_TAG}"
    IFS=$OLD_IFS
fi

# Bundle version (commits-on-master[-until-branch "." commits-on-branch])
# Assumes that two release branches will not diverge from the same commit on master.
if [ $(git rev-parse --abbrev-ref HEAD) = "master" ]; then
    MASTER_COMMIT_COUNT=$(git rev-list --count HEAD)
    BRANCH_COMMIT_COUNT=0
    BUNDLE_VERSION="$MASTER_COMMIT_COUNT"
else
    if [ $(git rev-list --count master..) = 0 ]; then   # The branch is attached to master. Just count master.
        MASTER_COMMIT_COUNT=$(git rev-list --count HEAD)
    else
        MASTER_COMMIT_COUNT=$(git rev-list --count $(git rev-list master.. | tail -n 1)^)
    fi
    BRANCH_COMMIT_COUNT=$(git rev-list --count master..)
    if [ $BRANCH_COMMIT_COUNT = 0 ]; then
        BUNDLE_VERSION="$MASTER_COMMIT_COUNT"
    else
        BUNDLE_VERSION="${MASTER_COMMIT_COUNT}.${BRANCH_COMMIT_COUNT}"
    fi
fi

/usr/libexec/PlistBuddy -c "Add :CFBundleBuildVersion string $BUILD_VERSION" "$INFO_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleBuildVersion $BUILD_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$INFO_PLIST"

# For debugging:
echo "BUILD VERSION: $BUILD_VERSION"
echo "LATEST_TAG: $LATEST_TAG"
echo "COMMIT_COUNT_SINCE_TAG: $COMMIT_COUNT_SINCE_TAG"
echo "SHORT VERSION: $SHORT_VERSION"
echo "MASTER_COMMIT_COUNT: $MASTER_COMMIT_COUNT"
echo "BRANCH_COMMIT_COUNT: $BRANCH_COMMIT_COUNT"
echo "BUNDLE_VERSION: $BUNDLE_VERSION"
