#
# Copyright (C) 2003,2004 Norwegian University of Science and Technology
#
# This file is part of Network Administration Visualized (NAV).
#
# NAV is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License version 2 as published by the Free
# Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
# more details.  You should have received a copy of the GNU General Public
# License along with NAV. If not, see <http://www.gnu.org/licenses/>.
#
"""HTTPS Service checker"""

import httplib
import socket
from urlparse import urlsplit
from nav import buildconf
from nav.statemon.DNS import socktype_from_addr
from nav.statemon.event import Event
from nav.statemon.abstractchecker import AbstractChecker

from ssl import wrap_socket

from python.nav.statemon.checker.HttpChecker import HttpChecker


class HTTPSConnection(httplib.HTTPSConnection):
    """Customized HTTPS protocol interface"""
    def __init__(self, timeout, host, port=443):
        httplib.HTTPSConnection.__init__(self, host, port)
        self.timeout = timeout
        self.connect()

    def connect(self):
        self.sock = socket.socket(socktype_from_addr(self.host),
                                  socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect((self.host, self.port))
        self.sock = wrap_socket(self.sock)


class HttpsChecker(HttpChecker):
    """HTTPS"""
    def connect(self, timeout, ip, port):
        return HTTPSConnection(timeout, ip, port)
