#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function, unicode_literals
import io
import os
import sys

from macdown_utils import execute


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
    write_transifex_config()
    execute(os.path.expanduser('~/Library/Python/2.7/bin/tx'), 'push', '-s')


if __name__ == '__main__':
    main()
