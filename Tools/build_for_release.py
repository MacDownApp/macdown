#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import os
import re
import subprocess
import shutil
import zipfile
from xml.etree import ElementTree


OPENSSL = '/usr/bin/openssl'
XCODEBUILD = '/usr/bin/xcodebuild'
OSASCRIPT = '/usr/bin/osascript'

BUILD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'Build')
APP_PATH = os.path.join(BUILD_DIR, 'MacDown.app')
ZIP_PATH = os.path.join(BUILD_DIR, 'MacDown.app.zip')


class CommandError(Exception):
    pass


def execute(*args):
    proc = subprocess.Popen(
        args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    stdout, stderr = proc.communicate()
    if proc.returncode:
        raise CommandError(
            '"{cmd}" failed with error {code}.\n {output}'.format(
                cmd=' '.join(args), code=proc.returncode, output=stderr
            )
        )
    return stdout


def print_value(key, value):
    print('{key}:\n{value}\n'.format(key=key, value=value))


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
        else:
            os.mkdir(BUILD_DIR)
    execute(
        XCODEBUILD, 'clean', '-workspace', 'MacDown.xcworkspace',
        '-scheme', 'MacDown',
    )

    print('Building application archive...')
    output = execute(
        XCODEBUILD, 'archive', '-workspace', 'MacDown.xcworkspace',
        '-scheme', 'MacDown',
    )
    match = re.search(r'^\s*ARCHIVE_PATH: (.+)$', output, re.MULTILINE)
    archive_path = match.group(1)
    print('Exporting application bundle...')
    execute(
        XCODEBUILD, '-exportArchive', '-exportFormat', 'app',
        '-archivePath', archive_path, '-exportPath', APP_PATH,
    )

    # Zip.
    with zipfile.ZipFile(ZIP_PATH, 'w') as f:
        for root, dirs, files in os.walk(APP_PATH):
            for file in files:
                f.write(os.path.join(root, file))

    raw_input(
        'Build finished. Press Return to display bundle information and '
        'reveal ZIP archive.'
    )

    print()
    print('DSA signature:')
    command = (
        '{openssl} dgst -sha1 -binary < "{zip_path}" | '
        '{openssl} dgst -dss1 -sign "{cert}" | '
        '{openssl} enc -base64'
    ).format(openssl=OPENSSL, zip_path=ZIP_PATH, cert=cert_path)
    os.system(command)
    print()

    print_value('Archive size', os.path.getsize(ZIP_PATH))

    with open(os.path.join(APP_PATH, 'Contents', 'Info.plist')) as plist:
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
        zip=os.path.abspath(ZIP_PATH)
    )
    execute(OSASCRIPT, '-e', script)


if __name__ == '__main__':
    import sys
    main(sys.argv)
