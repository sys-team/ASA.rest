ASA.rest
===========

arest/get
------------

Currently is in development.
The same as rest/get, but uses UOAuth instead of basic authorization.
User permissions are defined based on UOAuth/roles response on access token.

rest/get
------------

Returns result set of multi-entity query to ASA database.
Entities are joined with database defined foreign keys or with user defined conditions.
Result set contains fields of last entity in query.
Uses the basic http authentification. User permissions are the same as for a database user.

### options:

Any option can be passed as http-header or http-variable. 
When specifying an option as http-variable, a colon must be added to its name. (i.e.:distinct:=yes)

* authorization - UOAuth access token (for arest service)
* page-size -  rows per page, default 10
* page-number - page number from the beginning of a result set, default 1
* order-by - specify a field the result set will be ordered by, default field is 'id' if the result set contains one, otherwise no "order by" clause will be applied
* columns - comma separated list of the columns to return in a result set, default '*'
* order-dir - direction of an 'order by' clause, default is 'desc'
* distinct - if 'yes' distinct clause applies to query 
* long-values - if 'yes' shows long binary values in output. By default 'no' except then 'id' or 'xid' attribute
set for last entity in query or long binary column exactly defined in 'columns' option


### url syntax

    ../rest/get/<owner1>.<entityName1>[/[<entity expression>[&<entity expression>...]]]
    [/<owner2>.<entityName2>...][?<common filter expression>|<option>=<value>[&...]]
    
* entity expression:

  integer - value of 'id' column
  
  guid - value of 'xid' column
  
`<column name><logical operator><value>` - filter expression for entity. Supported logical operators: =, <, >, <=, >=, %= (sql 'like' operator) 
        
        
`<entity - n column name>``[``..]<entity column name>` - user defined join condition. n - number of entity left in url then current.
  n equals count of ` between column names.
  
* common filter expression: applies to all entity in the query which have column with name specified
  
`<column name><logical operator><value>` - Filters defined through variables applies to all entity in query which have column witn name = <column name>
  Supported logical operators is =, <, >, <=, >=, = `<list of comma separated values>` (sql 'in' operator)


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




