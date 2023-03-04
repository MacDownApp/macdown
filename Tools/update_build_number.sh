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

pushd `dirname $0` > /dev/null
source $(pwd -P)/utils.sh
popd > /dev/null

# CFBundleVersion:
#
# From https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleversion:
#
# > This key is a machine-readable string composed of one to three period-separated integers, such as 10.14.1. The string can only contain numeric characters (0-9) and periods.
# >
# > Each integer provides information about the build version in the format [Major].[Minor].[Patch]:
# > - Major: A major revision number.
# > - Minor: A minor revision number.
# > - Patch: A maintenance release number.
# >
# > You can include more integers but the system ignores them.
# >
# > You can also abbreviate the build version by using only one or two integers, where missing integers in the format are interpreted as zeros. For example, 0 specifies 0.0.0, 10 specifies 10.0.0, and 10.5 specifies 10.5.0.
# >
# > This key is required by the App Store and is used throughout the system to identify the version of the build. For macOS apps, increment the build version before you distribute a build.
#
# From https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-102364-TPXREF106:
#
# CFBundleVersion (String - iOS, macOS) specifies the build version number of the bundle, which identifies an iteration (released or unreleased) of the bundle.
#
# The build version number should be a string comprised of three non-negative, period-separated integers with the first integer being greater than zero—for example, 3.1.2. The string should only contain numeric (0-9) and period (.) characters. Leading zeros are truncated from each integer and will be ignored (that is, 1.02.3 is equivalent to 1.2.3). The meaning of each element is as follows:
#
# - The first number represents the most recent major release and is limited to a maximum length of four digits.
# - The second number represents the most recent significant revision and is limited to a maximum length of two digits.
# - The third number represents the most recent minor bug fix and is limited to a maximum length of two digits.
#
# If the value of the third number is 0, you can omit it and the second period.
#
# While developing a new version of your app, you can include a suffix after the number that is being updated; for example 3.1.3a1. The character in the suffix represents the stage of development for the new version. For example, you can represent development, alpha, beta, and final candidate, by d, a, b, and fc. The final number in the suffix is the build version, which cannot be 0 and cannot exceed 255. When you release the new version of your app, remove the suffix.

# CFBundleShortVersionString:
#
# From https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring:
#
# > This key is a user-visible string for the version of the bundle. The required format is three period-separated integers, such as 10.14.1. The string can only contain numeric characters (0-9) and periods.
# >
# > Each integer provides information about the release in the format [Major].[Minor].[Patch]:
# >
# > Major: A major revision number.
# > Minor: A minor revision number.
# > Patch: A maintenance release number.
# >
# > This key is used throughout the system to identify the version of the bundle.
#
# From https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html#//apple_ref/doc/uid/TP40009249-111349-TPXREF113:
#
# > CFBundleShortVersionString (String - iOS, macOS) specifies the release version number of the bundle, which identifies a released iteration of the app.
# >
# > The release version number is a string composed of three period-separated integers. The first integer represents major revision to the app, such as a revision that implements new features or major changes. The second integer denotes a revision that implements less prominent features. The third integer represents a maintenance release revision.
# >
# > The value for this key differs from the value for CFBundleVersion, which identifies an iteration (released or unreleased) of the app.
# >
# > This key can be localized by including it in your InfoPlist.strings files.

BUILD_VERSION=$(get_build_version)
SHORT_VERSION=$(get_short_version)
BUNDLE_VERSION=$(get_bundle_version)

# Alternatively, we could use Xcode's copy of the Git binary,
# but old Xcodes don't have this.
#GIT=$(xcrun -find git)

# Run Script build phases that operate on product files of the target that defines them should use the value of this build setting [TARGET_BUILD_DIR]. But Run Script build phases that operate on product files of other targets should use “BUILT_PRODUCTS_DIR” instead.
INFO_PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

/usr/libexec/PlistBuddy -c "Add :CFBundleBuildVersion string $BUILD_VERSION" "$INFO_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c "Set :CFBundleBuildVersion $BUILD_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $SHORT_VERSION" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUNDLE_VERSION" "$INFO_PLIST"
