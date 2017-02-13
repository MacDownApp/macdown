#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess


XCODEBUILD = '/usr/bin/xcodebuild'


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
