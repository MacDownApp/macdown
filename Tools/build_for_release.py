#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import os
import re
import shutil
import zipfile

from xml.etree import ElementTree

from macdown_utils import ROOT_DIR, XCODEBUILD, execute


try:
    input = raw_input
except NameError:   # Python 3 does not have raw_input.
    pass


OPENSSL = '/usr/bin/openssl'
OSASCRIPT = '/usr/bin/osascript'

BUILD_DIR = os.path.join(ROOT_DIR, 'Build')
APP_NAME = 'MacDown.app'
ZIP_NAME = 'MacDown.app.zip'

TERM_ENCODING = 'utf-8'


def print_value(key, value):
    print('{key}:\n{value}\n'.format(key=key, value=value))


def archive_dir(zip_f, directory):
    contents = os.listdir(directory)
    if not contents:    # Empty directory.
        info = zipfile.ZipInfo(directory)
        zip_f.writestr(info, '')
    for item in contents:
        full_path = os.path.join(directory, item)
        if os.path.islink(full_path):
            info = zipfile.ZipInfo(full_path)
            info.create_system = 3
            info.external_attr = 2716663808
            zip_f.writestr(info, os.readlink(full_path))
        elif os.path.isdir(full_path):
            archive_dir(zip_f, full_path)
        else:
            zip_f.write(full_path)


def main(argv):
    if len(argv) < 2:
        name = os.path.basename(argv[0])
        print('Usage: {name} private_key'.format(name=name))
        return

    cert_path = argv[1]

    print('Pre-build cleaning...')
    if os.path.exists(BUILD_DIR):
        try:
            shutil.rmtree(BUILD_DIR)
        except OSError:
            pass
    if not os.path.exists(BUILD_DIR):
        os.mkdir(BUILD_DIR)
    execute(
        XCODEBUILD, 'clean', '-workspace', 'MacDown.xcworkspace',
        '-scheme', 'MacDown',
    )

    print('Running external scripts...')
    os.chdir(os.path.join(ROOT_DIR, 'Dependency', 'peg-markdown-highlight'))
    execute('make')

    print('Building application archive...')
    os.chdir(BUILD_DIR)
    output = execute(
        XCODEBUILD, 'archive', '-workspace', '../MacDown.xcworkspace',
        '-scheme', 'MacDown',
    )
    if isinstance(output, bytes):
        output = output.decode(TERM_ENCODING)
    match = re.search(
        r'^\s*ARCHIVE_PATH: (.+)$',
        output,
        re.MULTILINE,
    )
    archive_path = match.group(1)
    print('Exporting application bundle...')
    execute(
        XCODEBUILD, '-exportArchive', '-exportFormat', 'app',
        '-archivePath', archive_path, '-exportPath', APP_NAME,
    )

    # Zip.
    with zipfile.ZipFile(ZIP_NAME, 'w') as f:
        archive_dir(f, APP_NAME)

    input(
        'Build finished. Press Return to display bundle information and '
        'reveal ZIP archive.'
    )

    print()
    print('DSA signature:')
    command = (
        '{openssl} dgst -sha1 -binary < "{zip_name}" | '
        '{openssl} dgst -dss1 -sign "{cert}" | '
        '{openssl} enc -base64'
    ).format(openssl=OPENSSL, zip_name=ZIP_NAME, cert=cert_path)
    os.system(command)
    print()

    print_value('Archive size', os.path.getsize(ZIP_NAME))

    with open(os.path.join(APP_NAME, 'Contents', 'Info.plist')) as plist:
        tree = ElementTree.parse(plist)
        root = tree.getroot()
        for infodict in root:
            has_key = None
            for child in infodict:
                if has_key == 'CFBundleVersion':
                    bundle_version = child.text
                    has_key = None
                elif has_key == 'CFBundleShortVersionString':
                    short_version = child.text
                    has_key = None
                elif child.tag == 'key':
                    has_key = child.text
    print_value('Bundle version', bundle_version)
    print_value('Short version', short_version)

    script = 'tell application "Finder" to reveal POSIX file "{zip}"'.format(
        zip=os.path.abspath(ZIP_NAME)
    )
    execute(OSASCRIPT, '-e', script)


if __name__ == '__main__':
    import sys
    main(sys.argv)
