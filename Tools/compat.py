#!/usr/bin/env python
# -*- coding: utf-8 -*-

_NOTHING = object()

try:
    import configparser
except ImportError:     # Python 2.
    import ConfigParser as configparser

    class ConfigParser(configparser.SafeConfigParser):
        """Compatibility layer.
        """
        def read_file(self, f, source=None):
            return self.readfp(f, source)

else:
    ConfigParser = configparser.ConfigParser
