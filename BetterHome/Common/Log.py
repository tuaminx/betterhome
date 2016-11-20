""" This module is Log object.
TODO:
1. Add config file in JSON
"""

import logging


class Log(logging.Logger):
    """The basic Logger

    """
    def __init__(self, name, log_file, level):
        self.name = name
        logging.basicConfig(format='%(asctime)-15s %(levelname)s %(message)s',
                            filename=log_file)
        self.log = logging.getLogger(self.name)
        self.log.level = logging.DEBUG if level is "debug" else logging.INFO

    def debug(self, msg):
        self.log.debug("[%s] : %s" % (self.name, msg))

    def info(self, msg):
        self.log.info("[%s] : %s" % (self.name, msg))

    def error(self, msg):
        self.log.error("[%s] : %s" % (self.name, msg))
