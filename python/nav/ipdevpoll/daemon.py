# -*- coding: utf-8 -*-
#
# Copyright (C) 2008-2011 UNINETT AS
#
# This file is part of Network Administration Visualized (NAV).
#
# NAV is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License version 2 as published by
# the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.  You should have received a copy of the GNU General Public
# License along with NAV. If not, see <http://www.gnu.org/licenses/>.
#
"""ipdevpoll daemon.

This is the daemon program that runs the IP device poller.

"""

import sys
import os
import logging
import signal
import time
from optparse import OptionParser

from twisted.internet import reactor

from nav import buildconf
import nav.daemon
import nav.logs
import nav.models.manage

import plugins
from nav.ipdevpoll import ContextFormatter


class IPDevPollProcess(object):
    """Main IPDevPoll process setup"""
    def __init__(self, options, args):
        self.options = options
        self.args = args
        self._logger = logging.getLogger('nav.ipdevpoll')

    def run(self):
        """Loads plugins, and initiates polling schedules."""
        # We need to react to SIGHUP and SIGTERM
        signal.signal(signal.SIGHUP, self.sighup_handler)
        signal.signal(signal.SIGTERM, self.sigterm_handler)

        plugins.import_plugins()
        # NOTE: This is locally imported because it will in turn import
        # twistedsnmp. Twistedsnmp is stupid enough to call
        # logging.basicConfig().  If imported before our own loginit, this
        # causes us to have two StreamHandlers on the root logger, duplicating
        # every log statement.
        from schedule import JobScheduler

        reactor.callWhenRunning(JobScheduler.initialize_from_config_and_run)
        reactor.addSystemEventTrigger("after", "shutdown", self.shutdown)
        reactor.run(installSignalHandlers=0)

    def sighup_handler(self, signum, frame):
        """Reopens log files."""
        self._logger.info("SIGHUP received; reopening log files")
        nav.logs.reopen_log_files()
        nav.daemon.redirect_std_fds(
            stderr=nav.logs.get_logfile_from_logger())
        self._logger.info("Log files reopened.")

    def sigterm_handler(self, signum, frame):
        """Cleanly shuts down logging system and the reactor."""
        self._logger.warn("SIGTERM received: Shutting down")
        self._shutdown_start_time = time.time()
        reactor.callFromThread(reactor.stop)

    def shutdown(self):
        self._log_shutdown_time()
        logging.shutdown()

    def _log_shutdown_time(self):
        sequence_time = time.time() - self._shutdown_start_time
        self._logger.warn("Shutdown sequence completed in %.02f seconds",
                          sequence_time)


class CommandProcessor(object):
    """Processes the command line and starts ipdevpoll."""
    pidfile = os.path.join(
        nav.buildconf.localstatedir, 'run', 'ipdevpolld.pid')

    def __init__(self):
        (self.options, self.args) = self.parse_options()
        self._logger = None

    def parse_options(self):
        parser = self.make_option_parser()
        (options, args) = parser.parse_args()
        return options, args

    def make_option_parser(self):
        """Sets up and returns a command line option parser."""
        parser = OptionParser(version="NAV " + buildconf.VERSION)
        parser.add_option("-c", "--config", dest="configfile",
                          help="read configuration from FILE", metavar="FILE")
        parser.add_option("-l", "--logconfig", dest="logconfigfile",
                          help="read logging configuration from FILE",
                          metavar="FILE")
        return parser

    def run(self):
        self.init_logging()
        self._logger = logging.getLogger('nav.ipdevpoll')
        self._logger.info("--- Starting ipdevpolld ---")
        self.exit_if_already_running()
        self.daemonize()
        nav.logs.reopen_log_files()
        self._logger.info("ipdevpolld now running in the background")

        self.start_ipdevpoll()

    def init_logging(self):
        """Initializes ipdevpoll logging for the current process."""
        formatter = ContextFormatter()

        # First initialize logging to stderr.
        stderr_handler = logging.StreamHandler(sys.stderr)
        stderr_handler.setFormatter(formatter)

        root_logger = logging.getLogger('')
        root_logger.addHandler(stderr_handler)

        nav.logs.set_log_levels()

        # Now try to load config and output logs to the configured file
        # instead.
        import config
        logfile_name = config.ipdevpoll_conf.get('ipdevpoll', 'logfile')
        if logfile_name[0] not in './':
            logfile_name = os.path.join(nav.buildconf.localstatedir,
                                        'log', logfile_name)

        file_handler = logging.FileHandler(logfile_name, 'a')
        file_handler.setFormatter(formatter)

        root_logger.addHandler(file_handler)
        root_logger.removeHandler(stderr_handler)

    def exit_if_already_running(self):
        # Check if already running
        try:
            nav.daemon.justme(self.pidfile)
        except nav.daemon.DaemonError, error:
            self._logger.error(error)
            sys.exit(1)

    def daemonize(self):
        try:
            nav.daemon.daemonize(self.pidfile,
                                 stderr=nav.logs.get_logfile_from_logger())
        except nav.daemon.DaemonError, error:
            self._logger.error(error)
            sys.exit(1)

    def start_ipdevpoll(self):
        process = IPDevPollProcess(self.options, self.args)
        process.run()

def main():
    """Main execution function"""
    processor = CommandProcessor()
    processor.run()

if __name__ == '__main__':
    main()
