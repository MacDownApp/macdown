# First, check for git in $PATH
hash git 2>/dev/null || { echo >&2 "Git required, not installed.  Aborting build number update script."; exit 0; }

# Use the latest tag for short version (expected tag format "vn[.n[.n]]")
# or if there are no tags, we make up version 0.0.<commit count>
function get_short_version() {
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
        local tools_dir=$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")
        local next_version=$(cat "$tools_dir/version.txt")
        SHORT_VERSION="${next_version}d${COMMIT_COUNT_SINCE_TAG}"
    fi
    echo $SHORT_VERSION
}

# Bundle version (commits-on-main[-until-branch "." commits-on-branch])
# Assumes that two release branches will not diverge from the same commit on main.
function get_bundle_version() {
    if [ $(git rev-parse --abbrev-ref HEAD) = "main" ]; then
        MAIN_COMMIT_COUNT=$(git rev-list --count HEAD)
        BRANCH_COMMIT_COUNT=0
        BUNDLE_VERSION="$MAIN_COMMIT_COUNT"
    else
        if [ $(git rev-list --count main..) = 0 ]; then   # The branch is attached to main. Just count main.
            MAIN_COMMIT_COUNT=$(git rev-list --count HEAD)
        else
            MAIN_COMMIT_COUNT=$(git rev-list --count $(git rev-list main.. | tail -n 1)^)
        fi
        BRANCH_COMMIT_COUNT=$(git rev-list --count main..)
        if [ $BRANCH_COMMIT_COUNT = 0 ]; then
            BUNDLE_VERSION="$MAIN_COMMIT_COUNT"
        else
            BUNDLE_VERSION="${MAIN_COMMIT_COUNT}.${BRANCH_COMMIT_COUNT}"
        fi
    fi
    echo $BUNDLE_VERSION
}
