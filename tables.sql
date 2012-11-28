create table if not exists table ar.collection(

    name varchar(512) not null unique,
    
    definition xml,


    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collection is 'Коллекция'
;