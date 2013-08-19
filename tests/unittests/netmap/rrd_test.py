import inspect
import os
import unittest
from mock import patch
import nav.netmap.rrd
from nav.models.rrd import RrdDataSource, RrdFile
from topology_layer2_testcase import TopologyLayer2TestCase
from topology_layer3_testcase import TopologyLayer3TestCase

class RrdNetmapTests(object):

    def setUp(self):
        super(RrdNetmapTests, self).setUp()
        self.path = os.path.dirname(inspect.getfile(inspect.currentframe()))
        self.test_data = []
        for i in xrange(0, 10):
            self.test_data.append(self._create_datasource(i))
        self.patch_datasources = patch.object(nav.netmap.rrd,
                                              "_get_datasources",
                                              return_value=self.test_data)
        self.patch_datasources.start()

    def tearDown(self):
        self.patch_datasources.stop()



    def _create_datasource(self, number):
        rrd_file = RrdFile()
        rrd_file.id = str(number + 200)
        rrd_file.filename = "%s/demo.rrd" % self.path
        rrd_file.value = str(number + 200)
        #rrd_file.netbox

        rrd_datasource = RrdDataSource()
        rrd_datasource.name = "ds" + str(number)
        rrd_datasource.id = str(number + 100)
        rrd_datasource.rrd_file = rrd_file
        rrd_datasource.description = "ifHCInOctets"
        rrd_datasource.type = "DERIVE"
        rrd_datasource.units = "bytes"
        rrd_datasource.threshold = 131072000

        return rrd_datasource

    def test_get_datasource_lookup(self):
        dict_lookup = nav.netmap.rrd._get_datasource_lookup([self.a1, self.b1, self.c3])

        self.assertEquals(len(self.test_data), len(dict_lookup.keys()))
        self.assertEquals('ds8', dict_lookup.get(208)[0].name)
        self.assertTrue(dict_lookup.get('NonExistingValue') is None)

class RrdNetmapLayer2Tests(RrdNetmapTests, TopologyLayer2TestCase):
    pass

class RrdNetmapLayer3Tests(RrdNetmapTests, TopologyLayer3TestCase):
    pass

if __name__ == '__main__':
    unittest.main()
