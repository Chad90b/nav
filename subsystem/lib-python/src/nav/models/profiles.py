# -*- coding: utf-8 -*-
#
# Copyright 2007-2008 UNINETT AS
#
# This file is part of Network Administration Visualized (NAV)
#
# NAV is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# NAV is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with NAV; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# Authors: Thomas Adamcik <thomas.adamcik@uninett.no>
#

"""Django ORM wrapper for profiles in NAV"""

__copyright__ = "Copyright 2007-2008 UNINETT AS"
__license__ = "GPL"
__author__ = "Thomas Adamcik (thomas.adamcik@uninett.no"
__id__ = "$Id$"

import logging
from datetime import datetime

from django.db import models
from django.db.models import Q

from nav.models.event import AlertQueue, AlertType, EventType, Subsystem
from nav.models.manage import Arp, Cam, Category, Device, GwPort, Location, \
    Memory, Netbox, NetboxCategory, NetboxInfo, NetboxType, Organization, \
    Prefix, Product, Room, Subcategory, SwPort, Usage, Vlan, Vendor

# This should be the authorative source as to which models alertengine supports.
# The acctuall mapping from alerts to data in these models is done the MatchField
# model.
SUPPORTED_MODELS = [
    # event models
    AlertQueue, AlertType, EventType, Subsystem,
    # manage models
    Arp, Cam, Category, Device, GwPort, Location, Memory, Netbox,
    NetboxCategory, NetboxInfo, NetboxType, Organization, Prefix,
    Product, Room, Subcategory, SwPort, Vendor, Vlan,
    Usage,
#                TypeGroup, Service,
]

_ = lambda a: a

#######################################################################
### Account models

class Account(models.Model):
    login = models.CharField(max_length=-1, unique=True)
    name = models.CharField(max_length=-1)
    password = models.CharField(max_length=-1)
    ext_sync = models.CharField(max_length=-1)

    class Meta:
        db_table = u'account'

    def __unicode__(self):
        return self.login

    def get_active_profile(self):
        return self.alertpreference.active_profile

class AccountGroup(models.Model):
    name = models.CharField(max_length=-1)
    description = models.CharField(max_length=-1, db_column='descr')
    accounts = models.ManyToManyField('Account') # FIXME this uses a view hack, was AccountInGroup

    class Meta:
        db_table = u'accountgroup'

    def __unicode__(self):
        return self.name

class AccountProperty(models.Model):
    account = models.ForeignKey('Account', db_column='accountid')
    property = models.CharField(max_length=-1)
    value = models.CharField(max_length=-1)

    class Meta:
        db_table = u'accountproperty'

    def __unicode__(self):
        return '%s=%s' % (self.property, self.value)

class AccountOrganization(models.Model):
    account = models.ForeignKey('Account', db_column='accountid')
    organization = models.CharField(max_length=30)

    class Meta:
        db_table = u'accountorg'

    def __unicode__(self):
        return self.orgid

class AlertAddress(models.Model):
    SMS = 2
    EMAIL = 1

    ALARM_TYPE = (
        (EMAIL, _('email')),
        (SMS, _('SMS')),
    )

    account = models.ForeignKey('Account', db_column='accountid')
    type = models.IntegerField(choices=ALARM_TYPE)
    address = models.CharField(max_length=-1, db_column='adresse')

    class Meta:
        db_table = u'alarmadresse'

    def __unicode__(self):
        return '%s by %s' % (self.address, self.get_type_display())

class AlertPreference(models.Model):
    account = models.OneToOneField('Account', primary_key=True,  db_column='accountid')
    active_profile = models.OneToOneField('AlertProfile', db_column='activeprofile', null=True)
    last_sent_day = models.DateTimeField(db_column='lastsentday')
    last_sent_week = models.DateTimeField(db_column='lastsentweek')

    class Meta:
        db_table = u'preference'

    def __unicode__(self):
        return 'preferences for %s' % self.account


#######################################################################
### Profile models

class AlertProfile(models.Model):
    account = models.ForeignKey('Account', db_column='accountid')
    name = models.CharField(max_length=-1, db_column='navn')
    time = models.TimeField(db_column='tid')
    weekday = models.IntegerField(db_column='ukedag')
    weektime = models.TimeField(db_column='uketid')

    class Meta:
        db_table = u'brukerprofil'

    def get_active_timeperiod(self):
        now = datetime.now()

        # Limit our query to the correct type of time periods
        if now.isoweekday() in [6,7]:
            valid_during = [TimePeriod.ALL_WEEK,TimePeriod.WEEKENDS]
        else:
            valid_during = [TimePeriod.ALL_WEEK,TimePeriod.WEEKDAYS]

        # The following code should get the currently active timeperiod.
        # If we don't find a timeperiod we use tp which will we the last
        # possilbe timeperiod (which wraps around to covering the first part of
        # the day.
        activve_timeperiod = None
        for tp in self.timeperiod_set.filter(valid_during__in=valid_during).order_by('start'):
            if not activve_timeperiod or (tp.start <= now.time()):
                activve_timeperiod = tp

        return activve_timeperiod or tp

    def __unicode__(self):
        return self.name

class TimePeriod(models.Model):
    ALL_WEEK = 1
    WEEKDAYS = 2
    WEEKENDS = 3

    VALID_DURING_CHOICES = (
        (ALL_WEEK, _('all days')),
        (WEEKDAYS, _('weekdays')),
        (WEEKENDS, _('weekends')),
    )

    profile = models.ForeignKey('AlertProfile', db_column='brukerprofilid')
    start = models.TimeField(db_column='starttid')
    valid_during = models.IntegerField(db_column='helg', choices=VALID_DURING_CHOICES)

    class Meta:
        db_table = u'tidsperiode'

    def __unicode__(self):
        return u'from %s for %s profile on %s' % (self.start, self.profile, self.get_valid_during_display())

class AlertSubscription(models.Model): # FIXME this needs a better name
    NOW = 0
    DAILY = 1
    WEEKLY = 2
    MAX = 3
    # FIXME according to profiles 3="Queue [Until profile changes]" ie next
    # time peroid, engine thinks that 3="NOW()-q.time>=p.queuelength AS max" ie
    # queu until alert has been in queue a certain number of days
    SUBSCRIPTION_TYPES = (
        (NOW, _('immediately')),
        (DAILY, _('daily at predefined time')),
        (WEEKLY, _('weekly at predefined time')),
        (MAX, _('at end of timeperiod')),
    )

    alarm_address = models.ForeignKey('AlertAddress', db_column='alarmadresseid')
    time_period = models.ForeignKey('TimePeriod', db_column='tidsperiodeid')
    filter_group = models.ForeignKey('FilterGroup', db_column='utstyrgruppeid')
    type = models.IntegerField(db_column='vent', choices=SUBSCRIPTION_TYPES)

    class Meta:
        db_table = u'varsle'

    def __unicode__(self):
        return 'alerts received %s should be %s to %s' % (self.time_period, self.get_type_display(), self.alarm_address)

    def send(self, alert):
        # FIXME handle queuing sending etc.
        logging.debug('alert %d: sending to %s with %s %s' % (alert.id, self.alarm_address.address, self.alarm_address.get_type_display(), self.get_type_display()))

#######################################################################
### Equipment models

class FilterGroupContent(models.Model):
    #            inc   pos
    # Add      |  1  |  1  | union in set theory
    # Sub      |  0  |  1  | exclusion
    # And      |  0  |  0  | intersection in set theory
    # Add inv. |  1  |  0  | complement of set

    include = models.BooleanField(db_column='inkluder')   # Include alert if filter macthes?
    positive = models.BooleanField(db_column='positiv')   # Negate match?
    priority = models.IntegerField(db_column='prioritet')

    filter = models.ForeignKey('Filter', db_column='utstyrfilterid')
    filter_group = models.ForeignKey('FilterGroup', db_column='utstyrgruppeid')

    class Meta:
        db_table = u'gruppetilfilter'
        ordering = ['priority']

    def __unicode__(self):
        if self.include:
            type = 'inclusive'
        else:
            type = 'exclusive'

        if not self.positive:
            type = 'inverted %s'  % type

        return '%s filter on %s' % (type, self.filter)

class Operator(models.Model):
    EQUALS = 0
    GREATER = 1
    GREATER_EQ = 2
    LESS = 3
    LESS_EQ = 4
    NOT_EQUAL = 5
    STARTSWITH = 6
    ENDSWITH = 7
    CONTAINS = 8
    REGEXP = 9
    WILDCARD = 10
    IN = 11

    # FIXME implment all of these in alertengine or disable those that don't
    # get implemeted.
    OPERATOR_TYPES = (
        (EQUALS, _('equals')),
        (GREATER, _('is greater')),
        (GREATER_EQ, _('is greater or equal')),
        (LESS, _('is less')),
        (LESS_EQ, _('is less or equal')),
        (NOT_EQUAL, _('not equals')),
        (STARTSWITH, _('starts with')),
        (ENDSWITH, _('ends with')),
        (CONTAINS, _('contains')),
        (REGEXP, _('regexp')),
        (WILDCARD, _('wildcard (? og *)')),
        (IN, _('in')),
    )
    OPERATOR_MAPPING = {
        EQUALS: '__exact',
        GREATER: '__gt',
        GREATER_EQ: '__gte',
        LESS: '__lt',
        LESS_EQ: '__lte',
        STARTSWITH: '__startswith',
        ENDSWITH: '__endswith',
        CONTAINS: '__contains',
        REGEXP: '__regex',
        IN: '__in',
    }

    IP_OPERATOR_MAPPING = {
        EQUALS: '=',
        GREATER: '>',
        GREATER_EQ: '>=',
        LESS: '<',
        LESS_EQ: '<=',
        NOT_EQUAL: '<>',
        CONTAINS: '>>=',
        IN: '<<=',
    }
    type = models.IntegerField(db_column='operatorid', choices=OPERATOR_TYPES)
    match_field = models.ForeignKey('MatchField', db_column='matchfieldid')

    class Meta:
        db_table = u'operator'
        unique_together = (('operator', 'match_field'),)

    def __unicode__(self):
        return u'%s match on %s' % (self.get_type_display(), self.match_field)

    def get_operator_mapping(self):
        # FIXME error catching
        return self.OPERATOR_MAPPING[self.type]

    def get_ip_operator_mapping(self):
        # FIXME error catching
        return self.IP_OPERATOR_MAPPING[self.type]


class Expresion(models.Model):
    equipment_filter = models.ForeignKey('Filter', db_column='utstyrfilterid')
    match_field = models.ForeignKey('MatchField', db_column='matchfelt')
    operator = models.IntegerField(db_column='matchtype', choices=Operator.OPERATOR_TYPES)
    value = models.CharField(max_length=-1, db_column='verdi')

    class Meta:
        db_table = u'filtermatch'

    def __unicode__(self):
        return '%s match on %s against %s' % (self.get_operator_display(), self.match_field, self.value)

class Filter(models.Model):
    id = models.IntegerField(primary_key=True)
    owner = models.ForeignKey('Account', db_column='accountid')
    name = models.CharField(max_length=-1, db_column='navn')

    class Meta:
        db_table = u'utstyrfilter'

    def __unicode__(self):
        return self.name

    def check(self, alert):
        filter = {}
        exclude = {}
        extra = {'where': [], 'params': []}

        for expresion in self.expresion_set.all():
            if expresion.match_field.data_type == MatchField.IP:
                # Trick the ORM into joining the tables we want
                lookup = '%s__isnull' % expresion.match_field.get_lookup_mapping()
                operator = Operator(type=expresion.operator).get_ip_operator_mapping()

                filter[lookup] = False

                extra['where'].append('%s %s %%s' % (expresion.match_field.value_id, operator))
                extra['params'].append(expresion.value)

            elif expresion.operator == Operator.WILDCARD:
                # Trick the ORM into joining the tables we want
                lookup = '%s__isnull' % expresion.match_field.get_lookup_mapping()
                filter[lookup] = False

                extra['where'].append('%s ILIKE %%s' % expresion.match_field.value_id)
                extra['params'].append(expresion.value)
            else:
                lookup = expresion.match_field.get_lookup_mapping() + Operator(type=expresion.operator).get_operator_mapping()

                if expresion.operator == Operator.IN:
                    filter[lookup] = expresion.value.split('|')
                elif expresion.operator == Operator.NOT_EQUAL:
                    exclude[lookup] = expresion.value
                else:
                    filter[lookup] = expresion.value

        filter['id'] = alert.id

        if not extra['where']:
            extra = {}

        logging.debug('alert %d: checking against filter %d with filter: %s, exclude: %s and extra: %s' % (alert.id, self.id, filter, exclude, extra))

        if AlertQueue.objects.filter(**filter).exclude(**exclude).extra(**extra).count():
            logging.debug('alert %d: matches filter %d' % (alert.id, self.id))
            return True

        logging.debug('alert %d: did not matche filter %d' % (alert.id, self.id))
        return False

class FilterGroup(models.Model):
    id = models.IntegerField(primary_key=True)
    owner = models.ForeignKey('Account', db_column='accountid', null=True)
    name = models.CharField(max_length=-1, db_column='navn')
    description = models.CharField(max_length=-1, db_column='descr')

    group_permisions = models.ManyToManyField('AccountGroup') # FIXME this uses view hack, was rettighet

    class Meta:
        db_table = u'utstyrgruppe'

    def __unicode__(self):
        return self.name

class MatchField(models.Model):
    # Attributes that define data type meanings:
    STRING = 0
    INTEGER = 1
    IP = 2

    DATA_TYPES = (
        (STRING, _('string')),
        (INTEGER, _('integer')),
        (IP, _('ip')),
    )
    # Attributes for the fields:

    # Unless the attribute name is prefixed with something we are refering to
    # the netbox connected to an alert.
    ALERT = 'alertq'
    ALERTTYPE = 'alerttype'
    ARP = 'arp'
    CAM = 'cam'
    CAT = 'cat'
    CATEGORY = 'category'
    DEVICE = 'device'
    EVENT_TYPE = 'eventtype'
    GWPORT = 'gwport'
    LOCATION = 'location'
    MEMORY = 'mem'
    MODULE = 'module'
    NETBOX = 'netbox'
    NETBOXINFO = 'netboxinfo'
    ORGANIZATION = 'org'
    PREFIX = 'prefix'
    PRODUCT = 'product'
    ROOM = 'room'
    SERVICE = 'service'
    SUBCATEGORY = 'subcat'
    SUBSYSTEM = 'subsystem'
    SWPORT = 'swport'
    TYPE = 'type'
#    TYPEGROUP = 'typegroup'
    VENDOR = 'vendor'
    VLAN = 'vlan'
    USAGE = 'usage'

    LOOKUP_FIELDS = (
        (ALERT, _('alert')),
        (ALERTTYPE, _('alert type')),
        (ARP, _('arp')),
        (CAM, _('cam')),
        (CAT, _('cat')),
        (CATEGORY, _('category')),
        (DEVICE, _('device')),
        (EVENT_TYPE, _('event type')),
        (GWPORT, _('GW-port')),
        (LOCATION, _('location')),
        (MEMORY, _('memeroy')),
        (MODULE, _('module')),
        (NETBOX, _('netbox')),
        (NETBOXINFO, _('netbox info')),
        (ORGANIZATION, _('organization')),
        (PREFIX, _('prefix')),
        (PRODUCT, _('product')),
        (ROOM, _('room')),
        (SERVICE, _('service')),
        (SUBCATEGORY, _('subcategory')),
        (SUBSYSTEM, _('subsystem')),
        (SWPORT, _('SW-port')),
        (TYPE, _('type')),
#        (TYPEGROUP, _('typegroup')),
        (VENDOR, _('vendor')),
        (VLAN, _('vlan')),
        (USAGE, _('usage')),
    )

    # This mapping designates how a MatchField relates to an alert. (yes the
    # formating is not PEP8, but it wouldn't be very readable otherwise)
    FOREIGN_MAP = {
        ARP:          'netbox__arp',
        CAM:          'netbox__cam',
        CAT:          'netbox__category',#FIXME
        DEVICE:       'netbox__device',
        EVENT_TYPE:   'event_type',
        GWPORT:       'netbox__connected_to_gwport',
        LOCATION:     'netbox__room__location',
        MEMORY:       'netbox__memory',
        MODULE:       'netbox__module',
        NETBOX:       'netbox',
        CATEGORY:     'netbox__category', #FIXME
        NETBOXINFO:   'netbox__info',
        ORGANIZATION: 'netbox__organization',
        PREFIX:       'netbox__prefix',
        PRODUCT:      'netbox__device__product',
        ROOM:         'netbox__room',
        SERVICE:      'netbox__', #FIXME
        SUBSYSTEM:    '', #FXIME
        SWPORT:       'netbox__connected_to_swport',
        TYPE:         'netbox__type',
#        TYPEGROUP:    'netbox__type__group', #FIXME
        USAGE:        'netbox__organization__vlan__usage', #FIXME
        VENDOR:       'netbox__device__product__vendor',
        VLAN:         'netbox__organization__vlan',
        SUBCATEGORY:  '', #FIXME
        ALERT:        '',
        ALERTTYPE:    'alert_type',
    }

    VALUE_MAP = {}
    # Build the mapping we need to be able to do checks.
    for model in SUPPORTED_MODELS:
        for field in model._meta.fields:
            VALUE_MAP['%s.%s' % (model._meta.db_table, field.db_column or field.attname)] = field.attname

    id = models.IntegerField(primary_key=True, db_column='matchfieldid')
    name = models.CharField(max_length=-1)
    description = models.CharField(max_length=-1, db_column='descr')
    value_help = models.CharField(max_length=-1, db_column='valuehelp')
    value_id = models.CharField(max_length=-1, db_column='valueid')
    value_name = models.CharField(max_length=-1, db_column='valuename')
    value_category = models.CharField(max_length=-1, db_column='valuecategory')
    value_sort = models.CharField(max_length=-1, db_column='valuesort')
    list_limit = models.IntegerField(db_column='listlimit')
    data_type = models.IntegerField(db_column='datatype', choices=DATA_TYPES)
    show_list = models.BooleanField(db_column='showlist')

    class Meta:
        db_table = u'matchfield'

    def __unicode__(self):
        return self.name

    def get_lookup_mapping(self):
        try:
            foreign_lookup = self.FOREIGN_MAP[self.value_id.split('.')[0]]
            value = self.VALUE_MAP[self.value_id]

            if foreign_lookup:
                return '%s__%s' % (foreign_lookup, value)
            return value

        except KeyError:
            logging.warn("Tried to lookup mapping for %s which is not supported" % self.value_id)
        return None


#######################################################################
### AlertEngine models

class SMSQueue(models.Model):
    id = models.IntegerField(primary_key=True)
    account = models.ForeignKey('Account', db_column='accountid')
    time = models.DateTimeField()
    phone = models.CharField(max_length=15)
    msg = models.CharField(max_length=145)
    sent = models.CharField(max_length=1, default='N') #FIXME change to boolean?
    smsid = models.IntegerField()
    time_sent = models.DateTimeField(db_column='timesent')
    severity = models.IntegerField()

    class Meta:
        db_table = u'smsq'

class AccountAlertQueue(models.Model):
    id = models.IntegerField(primary_key=True)
    account = models.ForeignKey('Account', db_column='accountid')
    addrress = models.ForeignKey('AlertAddress', db_column='addrid')
    alertid = models.IntegerField()
    insertion_time = models.DateTimeField(auto_now_add=True, db_column='time')

    class Meta:
        db_table = u'queue'
