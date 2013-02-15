grant connect to ar;
grant dba to ar;
comment on user ar is 'ASA.rest objects owner';

create table if not exists ar.collection(

    name varchar(512) not null unique,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collection is 'Коллекция'
;

create table if not exists ar.collectionLink(

    parentXid GUID,
    childXid GUID,

    not null foreign key(parent) references ar.collection on delete cascade,
    not null foreign key(child) references ar.collection on delete cascade,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collectionLink is 'Связь коллекций'
;

create table if not exists ar.element(

    elementXid GUID not null,
    collectionXid GUID not null,
    
    tableName varchar(512),
    
    not null foreign key(collection) references ar.collection on delete cascade,
    
    unique(collectionXid, elementXid),

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.element is 'Элемент'
;


