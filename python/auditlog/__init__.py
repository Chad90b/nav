# coding: UTF-8

# Copyright (C) 2017 UNINETT AS
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

from __future__ import unicode_literals


default_app_config = 'auditlog.apps.AuditlogConfig'

def find_modelname(obj):
    try:
        # Django <= 1.7.*
        return obj._meta.db_table
    except AttributeError:
        return obj