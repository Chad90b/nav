/*
=============================================
        NAVprofiles
    SQL Initialization script
    
    Run the command:
    psql navprofiles -f navprofiles.sql
    
    
	!! WARNING !!
	This SQL script is encoded as unicode (UTF-8),
	before you do changes and commit, be 100% sure
	that your editor do not mess it up.
    
    Check 1 : These norwegian letters looks nice:
    ! æøåÆØÅ !
    Check 2 : This is the Euro currency sign: 
    ! € !
=============================================
*/




/*
------------------------------------------------------
 DELETE OLD TABLES
------------------------------------------------------
*/

-- 1 ACCOUNT
DROP SEQUENCE account_id_seq;
DROP TABLE Account CASCADE;

-- 2 ACCOUNTGROUP
DROP SEQUENCE accountgroup_id_seq;
DROP TABLE AccountGroup CASCADE;

-- 3 ACCOUNTINGROUP
DROP TABLE AccountInGroup CASCADE;

-- 4 ACCOUNTPROPERTY
DROP TABLE AccountProperty CASCADE;

-- 5 ALARMADRESSE
DROP SEQUENCE alarmadresse_id_seq;
DROP TABLE Alarmadresse CASCADE;

-- 6 BRUKERPROFIL
DROP SEQUENCE brukerprofil_id_seq;
DROP TABLE Brukerprofil CASCADE;

-- 7 PREFERENCE
DROP TABLE Preference CASCADE;

-- 8 TIDSPERIODE
DROP SEQUENCE tidsperiode_id_seq;
DROP TABLE Tidsperiode CASCADE;

-- 9 UTSTYRGRUPPE
DROP SEQUENCE utstyrgruppe_id_seq;
DROP TABLE Utstyrgruppe CASCADE;

-- 10 VARSLE
DROP TABLE Varsle CASCADE;

-- 11 RETTIGHET
DROP TABLE Rettighet CASCADE;

-- 12 BRUKERRETTIGHET
DROP TABLE BrukerRettighet CASCADE;

-- 13 DEFAULTUTSTYR
DROP TABLE DefaultUtstyr CASCADE;

-- 14 UTSTYRFILTER
DROP SEQUENCE utstyrfilter_id_seq;
DROP TABLE Utstyrfilter CASCADE;

-- 15 GRUPPETILFILTER
DROP TABLE GruppeTilFilter CASCADE;

-- 16 MATCHFIELD
DROP SEQUENCE matchfield_id_seq;
DROP TABLE MatchField CASCADE;

-- 17 FILTERMATCH
DROP SEQUENCE filtermatch_id_seq;
DROP TABLE FilterMatch CASCADE;

-- 18 OPERATOR
DROP SEQUENCE operator_id_seq;
DROP TABLE Operator;

-- 19 LOGG
DROP SEQUENCE logg_id_seq;
DROP TABLE Logg CASCADE;

--DROP SEQUENCE smsq_id_seq;
DROP TABLE smsq CASCADE;

--DROP SEQUENCE queue_id_seq;
DROP TABLE queue CASCADE;

-- 22 NAVBARLINK
DROP SEQUENCE navbarlink_id_seq;
DROP TABLE NavbarLink CASCADE;

-- 23 ACCOUNTNAVBAR
DROP TABLE AccountNavbar;


-- AccountOrg
DROP TABLE AccountOrg;


-- Privileges

-- PrivilegeByGroup
DROP VIEW PrivilegeByGroup;

-- AccountGroupPrivilege
DROP TABLE AccountGroupPrivilege CASCADE;

DROP SEQUENCE privilege_id_seq;
DROP TABLE Privilege CASCADE;




/*
------------------------------------------------------
 TABLE DEFINITIONS
------------------------------------------------------
*/

/*
-- 1 ACCOUNT

Table for users

login		usally 3-8 characters
name		Real name of user
password	password for local authentication
ext_sync	external syncronization, reserved for future use, 
            null means local authentication
*/
CREATE SEQUENCE account_id_seq START 1000;
CREATE TABLE Account (
    id integer NOT NULL DEFAULT nextval('account_id_seq'),
    login varchar CONSTRAINT brukernavn_uniq UNIQUE NOT NULL,
    name varchar DEFAULT 'Noname',
    password varchar,
    ext_sync varchar,

    CONSTRAINT account_pk PRIMARY KEY (id)
);
CREATE INDEX account_idx ON Account(login);


/*
-- 2 ACCOUNTGROUP

Table for usergroup

name		Name of usergroup
descr		Longer description
*/
CREATE SEQUENCE accountgroup_id_seq START 1000;
CREATE TABLE AccountGroup (
       id integer NOT NULL DEFAULT nextval('accountgroup_id_seq'),
       name varchar DEFAULT 'Noname',
       descr varchar,

       CONSTRAINT accountgroup_pk PRIMARY KEY (id)
);


/*
-- 3 ACCOUNTINGROUP

Relation between user and usergroup. A user can be member of arbitrary many usergroups. 

*/
CREATE TABLE AccountInGroup (
       accountid integer NOT NULL,
       groupid integer NOT NULL,
       
       CONSTRAINT accountingroup_pk PRIMARY KEY(accountid, groupid),
       CONSTRAINT account_exist 
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE, 
       CONSTRAINT group_exist 
		  FOREIGN KEY(groupid) REFERENCES Accountgroup(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 4 ACCOUNTPROPERTY

A general table related to a single user. An user can have many account properties.
This is a general way that allows applications to add key-value pairs to a user.

In example NAVprofile web frontend use key 'language' to save language preferences for an user.
*/
CREATE TABLE AccountProperty (
    accountid integer,
    property varchar,
    value varchar,
    
    CONSTRAINT account_exist 
        FOREIGN KEY(accountid) REFERENCES Account(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE  
);

/*
-- 5 ALARMADRESSE

Addresses related to a user. A user can have arbitrary many addresses.

type		Specifies what kind of address this is.
                Predefined values:
                    1 e-mail user@domain.com
                    2 sms 99887766
                    3 irc nick!userid@irc.server.com
                    4 icq 123456789
adrese		The address
*/
CREATE SEQUENCE alarmadresse_id_seq START 1000;
CREATE TABLE Alarmadresse (
       id integer NOT NULL DEFAULT nextval('alarmadresse_id_seq'),
       accountid integer NOT NULL,
       type integer NOT NULL,
       adresse varchar,

       CONSTRAINT alarmadresse_pk PRIMARY KEY(id),
       CONSTRAINT account_exist 
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);


/*
-- 6 BRUKERPROFIL

A table for alertprofile. Only one profile can be active simultanously. It is possible that zero profiles are active. One user may have arbitrary many profiles. A profile is a composistion of a set of timeperiods which define a timetable.

navn		The name of the profile
tid		Related to queueing. When daily queueing is selected, this attrubute specify when on a day
            enqueued alerts will be sent.
ukedag		Related to queueing. When weekly queueing is selected, this attribute specify which 
            weekday enqueued alerts will be sent on. 0 is monday, 6 is sunday.
uketid		Related to queueing. When weekly queueing is selected, this attribute specify which time
            on the day enqueued alerts will be sent.

*/
CREATE SEQUENCE brukerprofil_id_seq START 1000;
CREATE TABLE Brukerprofil (
       id integer NOT NULL DEFAULT nextval('brukerprofil_id_seq'),
       accountid integer NOT NULL,
       navn varchar,
       tid time NOT NULL DEFAULT '08:00:00',
       ukedag integer NOT NULL DEFAULT 0,
       uketid time NOT NULL DEFAULT '08:30:00',

       CONSTRAINT brukerprofil_pk PRIMARY KEY(id),
       CONSTRAINT bruker_eksisterer
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);


/*
-- 7 PREFERENCE

queuelength	Related to queuing. When user select queueing this attributes speficies the highest number of
            days the user is allowed to queue an alert. Alerts that are older will be deleted by the 
            alertengine.
            
admin		an integer specifying wether the user is administrator or not.
            Defined values are (0 disabled, 1 normal user, 100 administrator)
            
activeprofile	Defines the active profile at the moment. null means no profiles is active.

sms		Is the user allowed to get alerts on sms.
*/
CREATE TABLE Preference (
    accountid integer NOT NULL,
    queuelength interval,
    admin integer NOT NULL DEFAULT 1,       
    activeprofile integer,
    sms boolean NOT NULL DEFAULT true, 
    
    lastsentday timestamp,
    lastsentweek timestamp,

    CONSTRAINT account_Exist
        FOREIGN KEY(accountid) REFERENCES Account(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
                  
    CONSTRAINT brukerprofil_eksisterer
        FOREIGN KEY(activeprofile) REFERENCES Brukerprofil(id)
        ON DELETE SET NULL
        ON UPDATE CASCADE
);

/*
-- 8 TIDSPERIODE

A table specifying a time period. This could be though of as an element in a timetable. A time period is related to a set of relation between equipmentgroups and alertaddresses.

starttid	this attribute speficies the start time of this time period. The time period end time is 
            implicit given by the start time by the next time period.
            1 all week
            2 weekdays Monday-Friday
            3 weekend Saturday-Sunday
            
helg		Speficies wether this time period is for weekdays or weekend or both.
*/
CREATE SEQUENCE tidsperiode_id_seq START 1000;
CREATE TABLE Tidsperiode (
       id integer NOT NULL DEFAULT nextval('tidsperiode_id_seq'),
       brukerprofilid integer NOT NULL,
       starttid time NOT NULL,
       helg integer NOT NULL,

       CONSTRAINT tidsperiode_pk PRIMARY KEY(id),
       CONSTRAINT brukerprofil_eksisterer
		  FOREIGN KEY(brukerprofilid) REFERENCES Brukerprofil(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 9 UTSTYRGRUPPE

Equipment group. An equipment is a composite of equipment filters. Equipment group is specified by a 
ennumerated (by priority) list of equipment filters. An equipment group could either be owned by an user, or shared among administrators.

navn	The name of the equipment group
descr	Longer description

*/
CREATE SEQUENCE utstyrgruppe_id_seq START 1000;
CREATE TABLE Utstyrgruppe (
    id integer NOT NULL DEFAULT nextval('utstyrgruppe_id_seq'),
    accountid integer,
    navn varchar,
    descr varchar,

    CONSTRAINT utstyrgruppe_pk PRIMARY KEY(id),
       
    CONSTRAINT account_Exist
        FOREIGN KEY(accountid) REFERENCES Account(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE  
);

/*
-- 10 VARSLE

Varsle is the relation between alert address, time period and equipment group.

vent		an integer specifying the queueing settings on this alert.
                    0 No queue, imediate delivery of alert
                    1 Enqueued (daily), daily delivery of alert digest
                    2 Enqueued (weekly), weekly delivery of alert digest
                    3 Enqueued (profile switch), alert is enqueued, and every time alertengine detects that
                a new time period is entered, this queue will be checked and delivered to the user or another
                queue if it match the new time periods alert settings.
*/
CREATE TABLE Varsle (
	alarmadresseid integer NOT NULL,
	tidsperiodeid integer NOT NULL,
	utstyrgruppeid integer NOT NULL,
	vent integer,

	CONSTRAINT varsleadresse_pk PRIMARY KEY(alarmadresseid, tidsperiodeid, utstyrgruppeid),
	CONSTRAINT alarmadresse_eksisterer
		FOREIGN KEY (alarmadresseid) REFERENCES Alarmadresse(id)
			ON DELETE CASCADE
			ON UPDATE CASCADE,

	CONSTRAINT tidsperiode_eksisterer
		FOREIGN KEY(tidsperiodeid) REFERENCES Tidsperiode(id)
			ON DELETE CASCADE
			ON UPDATE CASCADE,
	CONSTRAINT utstyrgruppe_eksisterer
		FOREIGN KEY(utstyrgruppeid) REFERENCES Utstyrgruppe(id)
			ON DELETE CASCADE
			ON UPDATE CASCADE  
);

/*
-- 11 RETTIGHET

Permissions.

This table contatins a relation from a user group to an equipment group. It gives all members of the 
actual user group permission to set up notofication for alerts matching this filter. The relation 
usergroup <-> equipment group is many to many.
*/
CREATE TABLE Rettighet (
       accountgroupid integer NOT NULL,
       utstyrgruppeid integer NOT NULL,
       CONSTRAINT rettighet_pk PRIMARY KEY(accountgroupid, utstyrgruppeid),
       CONSTRAINT accountgroup_exist
		  FOREIGN KEY(accountgroupid) REFERENCES accountgroup(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE,
       CONSTRAINT utstyrgruppe_eksisterer
		  FOREIGN KEY(utstyrgruppeid) REFERENCES Utstyrgruppe(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 12 BRUKERRETTIGHET

This is a permission relation table reserved for future use.

This adds permission from a user to quipmentgroups. In webfrontend, adding permission is still only available per user group. This is a suggested feature to be added later.. [10. juni 2003]

*/
CREATE TABLE BrukerRettighet (
       accountid integer NOT NULL,
       utstyrgruppeid integer NOT NULL,
       
       CONSTRAINT brukerrettighet_pk PRIMARY KEY(accountid, utstyrgruppeid),
       CONSTRAINT account_exist
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE,
       CONSTRAINT utstyrgruppe_eksisterer
		  FOREIGN KEY(utstyrgruppeid) REFERENCES Utstyrgruppe(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 13 DEFAULTUTSTYR

Default equipment is a table adding default quipmentgroups to user groups. Default equipment groups will be avaibale for the user through the webinterface to use for notifications/alerts.

The relation can be only to equipment groups shared by administrators, not to equipment groups owned by someone.
*/
CREATE TABLE DefaultUtstyr (
       accountgroupid integer NOT NULL,
       utstyrgruppeid integer NOT NULL,

       CONSTRAINT defaultutstyr_pk PRIMARY KEY (accountgroupid, utstyrgruppeid),
       CONSTRAINT utstyrgruppe_eksisterer
		  FOREIGN KEY(utstyrgruppeid) REFERENCES Utstyrgruppe(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE,
       CONSTRAINT accountgroup_exist
		  FOREIGN KEY(accountgroupid) REFERENCES AccountGroup(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 14 UTSTYRFILTER

Equipment filter, is a list of matches. An equipment filter will for a given alarm evaluate to either true
or false. For a filter to evaluate as true, all related filter matches has to evaluate to true.

The equipment filter could either be owned by an user, or shared among administrators. When accountid is null, the filter is shared among adminstrators.

navn		The name of the equipmentfilter
*/
CREATE SEQUENCE utstyrfilter_id_seq START 1000;
CREATE TABLE Utstyrfilter (
       id integer NOT NULL DEFAULT nextval('utstyrfilter_id_seq'),
       accountid integer,
       navn varchar,

       CONSTRAINT utstyrfilter_pk PRIMARY KEY(id),
       CONSTRAINT user_Exist
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE SET NULL 
		  ON UPDATE CASCADE
);

/*
-- 15 GRUPPETILFILTER

This table is an realtion from equipment group to eqipment filter. It is an enumerated relation, which
means that each row has a priority.

inkluder	include. If true the related filter is included in the group.
positiv		positive. If this is false, the filter is inverted, which implies that true is false, and
            false is true.
prioritet	priority. The list will be traversed in ascending priority order. Which means that the higher 
            number, the higher priority.
*/
CREATE TABLE GruppeTilFilter (
       inkluder boolean NOT NULL DEFAULT true,
       positiv boolean NOT NULL DEFAULT true,
       prioritet integer NOT NULL,
       utstyrfilterid integer NOT NULL,
       utstyrgruppeid integer NOT NULL,

       CONSTRAINT gruppetilfilter_pk PRIMARY KEY(utstyrfilterid, utstyrgruppeid),
       CONSTRAINT utstyrgruppeid_eksisterer 
		  FOREIGN KEY(utstyrgruppeid) REFERENCES Utstyrgruppe(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE,
       CONSTRAINT utstyrfilter_eksisterer 
		  FOREIGN KEY(utstyrfilterid) REFERENCES Utstyrfilter(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);

/*
-- 16 MATCHFIELD

Matchfield, is a relation to the Manage database. Each filtermatch could be related to a single matchfield.

name		The name of the filter
descr		Longer description
valuehelp	Help text in html about how to choose values.
valueid		Realtion to manage: table.field that defines the id
valuename	Realtion to manage: table.field describing the attribute name
valuecategory	Realtion to manage: table.field that categorize values
valuesort	Realtion to manage: table.field by which the values will be sorted in the option list.
listlimit	Max number of values shown in the drop down list.
datatype	Defining the datatype, this is a helper attribute for the alertengine.
showlist	boolean, true: show list of values from manage. false: show html input field.
*/
CREATE SEQUENCE matchfield_id_seq START 1000;
CREATE TABLE MatchField (
    matchfieldid integer NOT NULL DEFAULT nextval('matchfield_id_seq'),
    name varchar,
    descr varchar,
    valuehelp varchar,
    valueid varchar,
    valuename varchar,
    valuecategory varchar,
    valuesort varchar,
    listlimit integer DEFAULT 300,
    datatype integer NOT NULL DEFAULT 0,
    showlist boolean,
    
    CONSTRAINT matchfield_pk PRIMARY KEY(matchfieldid)
);

/*
-- 17 FILTERMATCH

Filtermatch is a single condition. It consist of a matchfield, a operator and a value.

matchfelt	This is a relation to matchfield
matchtype	This specifies the operator used. This a static list.
                Temporarily this list is used in the webinterface:
                    $type[0] = gettext('er lik');
                    $type[1] = gettext('er større enn');
                    $type[2] = gettext('er større eller lik');
                    $type[3] = gettext('er mindre enn');
                    $type[4] = gettext('er mindre eller lik');
                    $type[5] = gettext('er ulik');
                    $type[6] = gettext('starter med');
                    $type[7] = gettext('slutter med');
                    $type[8] = gettext('inneholder');
                    $type[9] = gettext('regexp');
                    $type[10] = gettext('wildcard (? og *)');
verdi		The value
*/
CREATE SEQUENCE filtermatch_id_seq START 1000;
CREATE TABLE FilterMatch (
       id integer NOT NULL DEFAULT nextval('filtermatch_id_seq'),
       utstyrfilterid integer NOT NULL,
       matchfelt integer NOT NULL,
       matchtype integer,
       verdi varchar,
       
    CONSTRAINT filtermatch_pk PRIMARY KEY(id),
    CONSTRAINT matchfield_Exist 
        FOREIGN KEY(matchfelt) REFERENCES matchfield(matchfieldid)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT utstyrfilter_eksisterer
        FOREIGN KEY(utstyrfilterid) REFERENCES Utstyrfilter(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);


/*
-- 18 OPERATOR

Operator, this is a list related to each matchfield, specifying which operator should be availbale to
choose from, form the given matchfield.

*/
CREATE SEQUENCE operator_id_seq START 1000;
CREATE TABLE Operator (
    operatorid integer NOT NULL DEFAULT nextval('operator_id_seq'),
    matchfieldid integer NOT NULL,
    
    CONSTRAINT operator_pk PRIMARY KEY (operatorid, matchfieldid),
    CONSTRAINT matchfield_eksisterer 
	FOREIGN KEY(matchfieldid) REFERENCES MatchField(matchfieldid)
            ON DELETE CASCADE
            ON UPDATE CASCADE
);


/*
-- 19 LOGG

Logg is a table where log events are collected.

type	type of log event.
        Static list:
            1 User logs in
            2 User logs out
            3 New
            4 Delete
            5 Edit
            6 New
            7 Delete
            8 Edit
            9 Profile switch via wap
tid	the time when event took place
descr	a general textstring, could be used to describe the event

*/
CREATE SEQUENCE logg_id_seq START 1000;
CREATE TABLE Logg (
    id integer NOT NULL DEFAULT nextval('logg_id_seq'),
       accountid integer NOT NULL,
       type integer,
       tid timestamptz,       
       descr varchar,
       
       CONSTRAINT loggid_pk PRIMARY KEY(id),     
       
       CONSTRAINT user_exist
		  FOREIGN KEY(accountid) REFERENCES Account(id)
		  ON DELETE CASCADE
		  ON UPDATE CASCADE
);


/*
-- 20 SMSQ

SMSQ Description

*/
CREATE TABLE smsq (
    id serial primary key, 
    accountid int references
        account(id) on update cascade on delete cascade, 
        
    time timestamp not null,
    phone varchar(15) not null,
    msg varchar(145) not null, 
    sent char(1) not null default 'N' 
        check (sent='Y' or sent='N' or sent='I'), 
    smsid int, 
    timesent timestamp, 
    severity int
);


/*
-- 21 Queue

QUEUE Description

*/
CREATE TABLE queue (
    id serial primary key, 
    accountid int references
        account(id) on update cascade on delete cascade, 
        
    addrid int references
        alarmadresse(id) on update cascade on delete cascade, 
        
    alertid int,
    time timestamp not null    
);

/*
-- 20 NAVBARLINK

Table for links in the navigation bar and dropdown menus. Links with
accountid 0 is shared by all.

accountid          owner of the link, id 0 means link is shared by all
name               one or two words describing the link, eg. Network
Explorer
uri                address of the link, eg. /vlanplot/index.html

*/
CREATE SEQUENCE navbarlink_id_seq START 1000;
CREATE TABLE NavbarLink (
    id integer NOT NULL DEFAULT nextval('navbarlink_id_seq'),
    accountid integer NOT NULL DEFAULT 0,
    name varchar,
    uri varchar,

    CONSTRAINT navbarlink_pk PRIMARY KEY (id),
    CONSTRAINT account_exists
               FOREIGN KEY (accountid) REFERENCES Account(id)
               ON DELETE CASCADE
               ON UPDATE CASCADE
);

/*
-- 21 ACCOUNTNAVBAR

Relation between account and navbarlinks, describing where the user wants
the link to be.

positions      'navbar', 'qlink1', 'qlink2' or a combination of these.

*/
CREATE TABLE AccountNavbar (
    accountid integer NOT NULL,
    navbarlinkid integer NOT NULL,
    positions varchar,

    CONSTRAINT accountnavbar_pk PRIMARY KEY (accountid, navbarlinkid),
    CONSTRAINT account_exists
               FOREIGN KEY (accountid) REFERENCES Account(id)
               ON DELETE CASCADE
               ON UPDATE CASCADE,
    CONSTRAINT navbarlink_exists
               FOREIGN KEY (navbarlinkid) REFERENCES NavbarLink(id)
               ON DELETE CASCADE
               ON UPDATE CASCADE
);

/*
-- AccountOrg

This table associates accounts with organizations.  Unfortunately, the
entity describing organizations is contained in the manage database,
so referential integrity must be enforced outside of the database
server.

*/
CREATE TABLE AccountOrg (
       accountid integer NOT NULL,
       orgid varchar(10) NOT NULL,

       CONSTRAINT accountorg_pk
                  PRIMARY KEY (accountid, orgid),
       CONSTRAINT account_exists
                  FOREIGN KEY(accountid) REFERENCES Account(id)
                  ON DELETE CASCADE
                  ON UPDATE CASCADE
);

/*
-- Privilege

This table contains valid privilege names and their id numbers for
reference from the AccountGroupPrivilege table

*/
CREATE SEQUENCE privilege_id_seq START 10000;
CREATE TABLE Privilege (
       privilegeid integer NOT NULL DEFAULT nextval('privilege_id_seq'),
       privilegename varchar(30) NOT NULL CONSTRAINT privilegename_uniq UNIQUE,

       CONSTRAINT privilege_pk PRIMARY KEY (privilegeid)
);

/*
-- AccountGroupPrivilege

This table defines privileges granted to AccountGroups.

*/
CREATE TABLE AccountGroupPrivilege (
       accountgroupid integer NOT NULL,
       privilegeid integer NOT NULL,
       target varchar NOT NULL,

       CONSTRAINT agprivilege_pk PRIMARY KEY (accountgroupid, privilegeid, target),
       CONSTRAINT accountgroup_exists
                  FOREIGN KEY(accountgroupid) REFERENCES AccountGroup(id)
                  ON DELETE CASCADE
                  ON UPDATE CASCADE,
       CONSTRAINT privilege_exists
                  FOREIGN KEY(privilegeid) REFERENCES Privilege
                  ON DELETE CASCADE
                  ON UPDATE CASCADE
);

/*
-- PrivilegeByGroup

This is a view that is similar to AccountGroupPrivilege, except that privilege names have been resolved from the privilege id
*/
CREATE VIEW PrivilegeByGroup AS (
       SELECT a.accountgroupid, b.privilegename AS action, a.target
       FROM AccountgroupPrivilege AS a NATURAL JOIN Privilege AS b
);

/*
------------------------------------------------------
 INSERT INITIAL DATA
------------------------------------------------------
*/


-- BRUKERE

INSERT INTO AccountGroup (id, name, descr) VALUES
(1, 'NAV Administrators', '');
INSERT INTO AccountGroup (id, name, descr) VALUES
(2, 'Anonymous users', 'Unauthenticated users (not logged in)');
INSERT INTO AccountGroup (id, name, descr) VALUES
(3, 'Restricted users', 'Users with restricted access');

INSERT INTO Account (id, login, name, password) VALUES
(0, 'default', 'Default User', '');
INSERT INTO Account (id, login, name, password) VALUES 
(1, 'admin', 'NAV Administrator', 'admin');

INSERT INTO AccountInGroup (accountid, groupid) VALUES 
(1, 1);

INSERT INTO Preference (accountid, admin, sms, queuelength) VALUES 
(1, 100, true, '14 days');
INSERT INTO Preference (accountid, admin, sms, queuelength) VALUES 
(0, 1, false, '14 days');

-- NAVBAR PREFERENCES

INSERT INTO NavbarLink (id, accountid, name, uri) VALUES
(1, 0, 'Preferences', '/preferences');
INSERT INTO NavbarLink (id, accountid, name, uri) VALUES
(2, 0, 'Toolbox', '/toolbox');

INSERT INTO AccountNavbar (accountid, navbarlinkid, positions) VALUES
(0, 1, 'navbar');
INSERT INTO AccountNavbar (accountid, navbarlinkid, positions) VALUES
(0, 2, 'navbar');

-- Privileges

INSERT INTO Privilege VALUES (1, 'empty_privilege');
INSERT INTO Privilege VALUES (2, 'web_access');
INSERT INTO Privilege VALUES (3, 'alert_by');

/*
  Set some default web_access privileges
*/
-- Administrators get full access
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (1, 2, '.*');
-- Anonymous users need access to a few things, like the login page and images and soforth
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/index.py/login\\b');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/images/.*');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/wap/.*');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/alertprofiles/wap/.*');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/$');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/index.py/index$');
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (2, 2, '^/toolbox\b');
-- Gives access to most tools for restricted users (during alpha testing, at least)
INSERT INTO AccountGroupPrivilege (accountgroupid, privilegeid, target) VALUES (3, 2, '^/(index|report|status|editdb|emotd|alertprofiles|devicemanagement|machinetracker)/?');

-- Matchfields

/* Matchfield.Datatype
string:  0
integer: 1
ip adr:  2
*/

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr, valuehelp) VALUES 
(10, 0, 'Event type', 'eventtype.eventtypeid', 'eventtype.eventtypeid', null, 'eventtype.eventtypeid', true, 
'Event type: An event type describes a category of alarms. (Please note that alarm type is a more refined attribute. There are a set of alarm types within an event type.)', 
'Event types:<p><ul>
<li><b>boxState</b>: Tells us whether a network-unit is down or up.</li>
<li><b>serviceState</b>: Tells us whether a service on a server is up or down.</li>
<li><b>moduleState</b>: Tells us whether a module in a device is working or not.</li>
<li><b>thresholdState</b>: Tells us whether the load has passed a certain threshold.</li>
<li><b>linkState</b>: Tells us whether a link is up or down.</li>
<li><b>coldStart</b>: Tells us that a network-unit has done a coldstart</li>
<li><b>warmStart</b>: Tells us that a network-unit has done a warmstart</li>
<li><b>info</b>: Tells us that a network-unit has done a warmstart</li>
<li><b>maintenanceState</b>: Tells us if something is set on maintenance.</li>
</ul>');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 10);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(11, 0, 'Alert type', 'alerttype.alerttype', 'alerttype.alerttypedesc|[ID]: [NAME]', 'alerttype.eventtypeid', 'alerttype.alerttypeid', true, 
'Alert type: An alert type describes the various values an event type may take.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 11);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(12, 0, 'Category', 'cat.catid', 'cat.descr|[ID]: [NAME]', null, 'cat.descr', true, 
'Category: All equipment is categorized in 7 main categories.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 12);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(13, 0, 'Sub category', 'subcat.subcatid', 'subcat.descr|[ID]: [NAME]', 'subcat.catid', 'subcat.descr', true, 
'Sub category: Within a catogory user-defined subcategories may exist.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 13);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(14, 0, 'Sysname', 'netbox.netboxid', null, null, null, false, 
'Sysname: Limit your alarms based on sysname.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 14);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (5, 14);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (6, 14);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (7, 14);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (8, 14);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (9, 14);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr, valuehelp) VALUES 
(15, 2, 'IP address', 'netbox.ip', null, null, null, false,
'Limit your alarms based on an IP address/range (prefix)',
'examples:<blockquote>
129.241.190.190<br>
129.241.190.0/24</br>
129.241.0.0/16</blockquote>');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 15);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(16, 0, 'Organization', 'org.orgid', 'org.descr|[NAME] ([ID])', 'org.parent', 'org.descr', true, 
'Organization: Limit your alarms based on the organization ownership of the alarm in question.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 16);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(17, 0, 'Room', 'room.roomid', 'room.descr|[ID]: [NAME]', 'room.locationid', 'room.roomid', true, 
'Room: Limit your alarms based on room.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 17);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(18, 0, 'Location', 'location.locationid', 'location.descr', null, 'location.descr', true, 
'Location: Limit your alarms based on location (a location contains a set of rooms) ');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 18);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(19, 0, 'Usage', 'usage.usageid', 'usage.descr', null, 'usage.descr', true, 
'Usage: Different network prefixes are mapped to usage areas.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 19);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(20, 0, 'Type', 'type.typeid', 'type.descr', 'type.vendorid', 'type.descr', true, 
'Type: Limit your alarms equipment type');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 20);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr) VALUES 
(21, 0, 'Equipment vendor', 'vendor.vendorid', 'vendor.vendorid', null, 'vendor.vendorid', true,
'Equipment vendor: Limit alert by the vendor of the netbox.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 21);

INSERT INTO MatchField (matchfieldid, datatype, name, valueid, valuename, valuecategory, valuesort, showlist, descr,valuehelp) VALUES 
(22, 1, 'Severity', 'alertq.severity', null, null, null, false, 
'Severity: Limit your alarms based on severity.',
'Range: Severities are in the range 0-100, where 100 is most severe.');
INSERT INTO Operator (operatorid, matchfieldid) VALUES (0, 22);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (1, 16);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (2, 16);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (3, 16);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (4, 16);
INSERT INTO Operator (operatorid, matchfieldid) VALUES (5, 16);






/*
------------------------------------------------------
 GRANT PERMISSIONS
------------------------------------------------------
*/

CREATE OR REPLACE FUNCTION nav_grant(TEXT, BOOL) RETURNS INTEGER AS '
  DECLARE
    tables_rec   RECORD;
    counter      INTEGER;
    user_name    ALIAS FOR $1;
    write_access ALIAS FOR $2;
    use_priv     TEXT := ''SELECT'';
  BEGIN
    counter := 0;
    IF write_access THEN
      use_priv := ''ALL'';
    END IF;

    FOR tables_rec IN SELECT * FROM pg_tables WHERE schemaname=''public'' LOOP
      EXECUTE ''GRANT '' || use_priv
               || '' ON '' || quote_ident(tables_rec.tablename)
               || '' TO '' || quote_ident(user_name)
               || '';'';
      counter := counter + 1;
    END LOOP;

    FOR tables_rec IN SELECT * FROM pg_views WHERE schemaname=''public'' LOOP
      EXECUTE ''GRANT '' || use_priv
               || '' ON '' || quote_ident(tables_rec.viewname)
               || '' TO '' || quote_ident(user_name)
               || '';'';
      counter := counter + 1;
    END LOOP;

    FOR tables_rec IN SELECT * FROM pg_statio_all_sequences WHERE schemaname=''public'' LOOP
      EXECUTE ''GRANT '' || use_priv
               || '' ON '' || quote_ident(tables_rec.relname)
               || '' TO '' || quote_ident(user_name)
               || '';'';
      counter := counter + 1;
    END LOOP;

    RETURN counter;
  END;
' LANGUAGE 'plpgsql';


SELECT nav_grant('navread', false);
SELECT nav_grant('navwrite', true);

/*
------------------------------------------------------
 EOF
------------------------------------------------------
*/
