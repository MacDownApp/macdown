# First, check for git in $PATH
hash git 2>/dev/null || { echo >&2 "Git required, not installed.  Aborting build number update script."; exit 0; }

# Use the contents of the version.txt file.
function get_short_version() {
    local tools_dir=$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")
    cat "$tools_dir/version.txt"
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
