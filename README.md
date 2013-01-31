ASA.rest
============

rest/addElement
------------

rest/get
------------

returns rows from table or stored procedure result set

### url

    .../<owner>.<entityName>[/<xid or id>][?<columnName = filterExpression>...]

### variables:

* code - UOAuth access token
* page-size: -  rows per page, default 10
* page-number: - number of page from resulr set, default 1
* order-by: - order by expression, default 'id', if table or sp result set does not have 'id' column, no order by
* columns: - list of columns to select default '*'

### returns:

xml with rows


    url: ../rest/get/dbo.someTable?page-size:=1&page-number:=5
    
    <response xmlns="https://github.com/sys-team/ASA.rest" xid="0000" ts="2013-01-30 15:30:08.919"
      cts="2013-01-30 15:30:08.716" servername="SERVER" dbname="database" host="HOST">
        <d name="dbo.someTable" xid="0000">
            <integer name="id">1</integer>
            <string name="name">Unit</string>
            <datetime name="ts">2009-04-29 15:40:29.733</datetime>
        </d>
    </response>

rest/link
------------

rest/make
------------

rest/put
------------


