#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function, unicode_literals
import io
import os
import sys

from xml.etree import ElementTree

from macdown_utils import XLIFF_URL, execute


# Translations of these keys will be dropped.
NO_TRANSLATE_KEYS = {
    'MacDown/MacDown-Info.plist': [
        'CFBundleName',
        'CFBundleShortVersionString',
    ],
    'MacDownTests/MacDownTests-Info.plist': [
        'CFBundleShortVersionString',
    ],
}


ElementTree.register_namespace('', XLIFF_URL)


def write_transifex_config():
    """Used to setup Travis for Transifex push.

    Requires environ "TRANSIFEX_PASSWORD".
    """
    transifexrc_path = os.path.expanduser('~/.transifexrc')
    if os.path.exists(transifexrc_path):
        return
    with io.open(transifexrc_path, 'w', encoding='utf-8') as f:
        f.write((
            '[https://www.transifex.com]\n'
            'hostname = https://www.transifex.com\n'
            'password = {password}\n'
            'token = \n'
            'username = macdown\n'
        ).format(password=os.environ['TRANSIFEX_PASSWORD']))


PREFIX_MAP = {'xliff': XLIFF_URL}


def clean_xliff():
    xliff_dirpath = os.getenv('LOCALIZATION_OUT')
    assert xliff_dirpath
    for fn in os.listdir(xliff_dirpath):
        if os.path.splitext(fn)[-1] != '.xliff':
            continue
        xliff_filepath = os.path.join(xliff_dirpath, fn)
        tree = ElementTree.parse(xliff_filepath)

        # Remove keys that should not be translated.
        for source, keys in NO_TRANSLATE_KEYS.items():
            bodyxpath = 'xliff:file[@original="{}"]/xliff:body'.format(source)
            bodynode = tree.find(bodyxpath, PREFIX_MAP)
            for key in keys:
                nodexpath = '*[@id="{}"]'.format(key)
                node = bodynode.find(nodexpath, PREFIX_MAP)
                if node:
                    bodynode.remove(node)

        tree.write(
            xliff_filepath,
            encoding='UTF-8', xml_declaration=True, method='xml',
        )


def main():
    if os.getenv('TRAVIS_PULL_REQUEST') != 'false':
        print('Build triggered by a pull request. Transifex push skipped.',
              file=sys.stderr)
        return
    current_branch = os.getenv('TRAVIS_BRANCH')
    target_branch = 'master'
    if current_branch != target_branch:
        print('Branch {cur} is not {target}. Transifex push skipped.'.format(
            cur=current_branch, target=target_branch,
        ), file=sys.stderr)
        return
    clean_xliff()
    write_transifex_config()
    execute(os.path.expanduser('~/Library/Python/2.7/bin/tx'), 'push', '-s')


if __name__ == '__main__':
    main()
