#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging
import os
import shutil

from xml.etree import ElementTree

from compat import ConfigParser
from macdown_utils import ROOT_DIR, XCODEBUILD, execute


TX_CONFIG_FILE = os.path.join(ROOT_DIR, '.tx', 'config')
XLIFF_URL = 'urn:oasis:names:tc:xliff:document:1.2'


logger = logging.getLogger()


ElementTree.register_namespace('', XLIFF_URL)


def pull_translations(parser):
    xliff_dirpath = os.path.dirname(
        parser.get('macdown.macdownxliff', 'file_filter'),
    )
    for fn in os.listdir(xliff_dirpath):
        os.remove(os.path.join(xliff_dirpath, fn))
    os.system('tx pull -a')


def parse_tx_config():
    parser = ConfigParser()
    with open(TX_CONFIG_FILE) as f:
        parser.read_file(f)
    return parser


def fix_translation_codes(parser):
    # Get language code mapping (Transifex, Xcode).
    def parse_lang_pair(s):
        f, t = (c.strip() for c in s.split(':'))
        return f.replace('_', '-'), t

    code_map = dict(
        parse_lang_pair(keymap)
        for keymap in parser.get('main', 'lang_map').split(',')
    )

    # Get the file pattern.
    xliff_dirpath = os.path.dirname(
        parser.get('macdown.macdownxliff', 'file_filter'),
    )
    for fn in os.listdir(xliff_dirpath):
        if os.path.splitext(fn)[-1] != '.xliff':
            continue
        xliff_filepath = os.path.join(xliff_dirpath, fn)
        logger.info('Fixing {}'.format(xliff_filepath))

        tree = ElementTree.parse(xliff_filepath)

        # Fix language codes.
        for node in tree.iterfind('xliff:file', {'xliff': XLIFF_URL}):
            try:
                new_code = code_map[node.get('target-language')]
            except KeyError:
                pass
            else:
                node.set('target-language', new_code)

        tree.write(
            xliff_filepath,
            encoding='UTF-8', xml_declaration=True, method='xml',
        )


def import_translations(parser):
    source_lang = parser.get('macdown.macdownxliff', 'source_lang')
    xliff_dirpath = os.path.dirname(
        parser.get('macdown.macdownxliff', 'file_filter'),
    )
    for fn in os.listdir(xliff_dirpath):
        stem, ext = os.path.splitext(fn)
        if ext != '.xliff' or stem == source_lang:
            continue
        logger.info('Importing {}'.format(fn))
        execute(
            XCODEBUILD, '-importLocalizations',
            '-localizationPath', os.path.join(xliff_dirpath, fn),
        )


def main():
    logging.basicConfig(level=logging.INFO)
    parser = parse_tx_config()
    pull_translations(parser)
    fix_translation_codes(parser)
    import_translations(parser)


if __name__ == '__main__':
    main()
