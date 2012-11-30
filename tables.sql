create table if not exists ar.collection(

    name varchar(512) not null unique,
    code varchar(128) not null unique,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collection is 'Коллекция'
;

create table if not exists ar.collectionTable(

    tableName varchar(512) not null,
    whereClause long varchar,
    
    not null foreign key(collection) references ar.collection on delete cascade,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collection is 'Таблица коллекции'
;

create table if not exists ar.collectionCollection(
    not null foreign key(collection) references ar.collection on delete cascade,
    not null foreign key(parentCollection) references ar.collection on delete cascade,

    id ID, xid GUID, ts TS, cts CTS,
    unique (xid), primary key (id)
)
;
comment on table ar.collection is 'Коллекция коллекции'
;
