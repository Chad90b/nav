#!/bin/bash -x
cd ${WORKSPACE}
cloc \
    --exclude-dir=.env,.idea,tmp,build,doc,htdocs/static/css,htdocs/static/js/libs,htdocs/static/js/node_modules,htdocs/static/js/geomap/projdefs,python/nav/smidumps,python/nav/enterprise,tests/assets,tests/functional-report.html \
    --exclude-lang=make,m4,XML \
    --not-match-f='(configure|config.status)$' \
    --by-file \
    --xml \
    --out="${WORKSPACE}/cloc.xml" \
    .
