#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import subprocess


XCODEBUILD = '/usr/bin/xcodebuild'

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class CommandError(Exception):
    pass


def execute(*args):
    proc = subprocess.Popen(
        args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    )
    stdout, stderr = map(lambda s: s.decode('utf-8'), proc.communicate())
    if proc.returncode:
        raise CommandError(
            '"{cmd}" failed with error {code}.\n {output}'.format(
                cmd=' '.join(args), code=proc.returncode, output=stderr
            )
        )
    return stdout
