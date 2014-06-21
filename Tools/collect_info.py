#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function
import os
import zipfile
from xml.etree import ElementTree


OPENSSL = '/usr/bin/openssl'


def main(argv):
    if len(argv) < 3:
        name = os.path.basename(argv[0])
        print('Usage: {name} update_archive private_key'.format(name=name))
        return

    archive_path = argv[1]
    cert_path = argv[2]
    print()

    print('DSA signature:')
    command = (
        '{openssl} dgst -sha1 -binary < "{archive}" | '
        '{openssl} dgst -dss1 -sign "{cert}" | '
        '{openssl} enc -base64'
    ).format(openssl=OPENSSL, archive=archive_path, cert=cert_path)
    os.system(command)
    print()

    print('Archive size:')
    print(os.path.getsize(archive_path))
    print()

    archive = zipfile.ZipFile(argv[1])
    version = None
    with archive.open('MacDown.app/Contents/Info.plist') as plist:
        tree = ElementTree.parse(plist)
        root = tree.getroot()
        for infodict in root:
            has_key = False
            for child in infodict:
                if has_key:
                    version = child.text
                    break
                if child.tag == 'key' and child.text == 'CFBundleVersion':
                    has_key = True
    print('Bundle version:')
    print(version)
    print()


if __name__ == '__main__':
    import sys
    main(sys.argv)
