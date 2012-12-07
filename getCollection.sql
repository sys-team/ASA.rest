create or replace function ar.getCollection(
    @collection integer,
    @pageSize integer,
    @pageNumber integer)
returns xml
begin
    declare @result xml;
    declare @tableId integer;
    declare @name long varchar;
    declare @xid GUID;
    
    select name,
           xid
      into @name, @xid
      from ar.collection
     where id = @collection;
    
    for llooop as ccur cursor for
    select distinct tableName as c_tableName
      from ar.element
     where collection = @collection
    do

    -- table
        set @tableId = (select st.table_id
                          from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                         where st.table_name =  substr(c_tableName, locate(c_tableName,'.') +1)
                           and su.user_name =  left(c_tableName, locate(c_tableName,'.') -1));
        
        if @tableId is not null then
            set @result = xmlconcat(@result, ar.getTable(c_tableName, @tableId, @pageSize, @pageNumber, 'id', @collection));
        end if;
    end for;
    
    -- collection
    for lloop2 as ccur2 cursor for
    select l.child as c_child,
           l.childXid as c_childXid,
           c.name as c_name
      from ar.collectionLink l join ar.collection c on l.child = c.id
     where l.parent = @collection
    do
        --set @result = xmlconcat(@result, ar.getCollection(c_child, @pageSize, @pageNumber));
        set @result = xmlconcat(@result, xmlelement('collection', xmlattributes(c_name as "parent", c_childXid as "parent-xid")));
    end for;
    
    set @result = xmlelement('collection', xmlattributes(@name as "name", @xid as "xid"), @result);
    
    return @result;
end
;