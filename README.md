ASA.rest
============

arest/get
------------

In development now.
The same as rest/get, but uses UOAuth authorization instead of basic.
User permissions defines based on UOAuth/roles response on access token.

rest/get
------------

Returns result set of multi-entity query to ASA database. Joins entities based on foreign keys defined in database
or user defined join condition. Result set contains fields of last enity in query.
Uses the basic http authentification. User permissions the same as for database user.

### options:

Any option can be passed as http-header or http-variable. If passing as http-variable need colon be added to option name.

* authorization - UOAuth access token (for arest service)
* page-size -  rows per page, default 10
* page-number - number of page from result set, default 1
* order-by - order by expression, default 'id', if table or sp result set does not have 'id' column, no order by
* columns - list of columns to select, default '*'
* order-dir - order by direction, default is 'desc'
* distinct - if 'yes' distinct clause applies to query 
* long-values - if 'yes' shows long binary values in output. By default 'no' except then 'id' or 'xid' attribute
set for last entity in query or long binary column exactly defined in 'columns' option


### url syntax

    ../rest/get/<owner1>.<entityName1>[/[<entity expression>[&<entity expression>...]]]
    [/<owner2>.<entityName2>...][?<common filer expression>|<option>=<value>[&...]]
    
* entity expression:

  integer - value of 'id' column
  
  guid - value of 'xid' column
  
    <column name><logical operator><value> - filter expression for entity. Supported logical operators: =, <, >, <=, >=
  
    <entity - n column name>`[`..]<entity column name> - user defined join condition. n - number of entity left in url then current.
  n equals count of ` between column names.
  
* common filter expression:
  
  <column name><logical operator><value> - Filters defined through variables applies to all entity in query which have column witn name = <column name>
  Supported logical operators is =, <, >, <=, >=, in
 

### returns:

xml with rows of last entity in query


    url: ../rest/get/dbo.someTable//dbo.someTable2/10?page-size:=1&page-number:=5
    
    <response xmlns="https://github.com/sys-team/ASA.rest" xid="0000" ts="2013-01-30 15:30:08.919"
      cts="2013-01-30 15:30:08.716" servername="SERVER" dbname="database" host="HOST">
        <d name="dbo.someTable2" xid="0000">
            <integer name="id">10</integer>
            <string name="name">Unit</string>
            <datetime name="ts">2009-04-29 15:40:29.733</datetime>
        </d>
    </response>




