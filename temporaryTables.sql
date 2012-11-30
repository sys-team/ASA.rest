create global temporary table ar.log(
    
    url long varchar,
    variables long varchar,
    response xml,
    requestor varchar(1024) default current user,

    callerIP varchar(16) default connection_property('ClientNodeAddress'),

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
    
)  not transactional share by all
;