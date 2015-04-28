if exists (select * from sys.systable t join sys.sysuserperm p on t.creator = p.user_id where table_name = 'log' and user_name = 'ar') then
    drop table ar.log
end if
;

create global temporary table ar.log(
    
    url long varchar,
    variables long varchar,
    response xml,
    requestor varchar(1024) default current user,
    code varchar(1024),
    account int,

    httpBody long varchar default http_body(),
    callerIP varchar(128) default connection_property('ClientNodeAddress'),
    sqlText long varchar,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
    
)  not transactional share by all
;

