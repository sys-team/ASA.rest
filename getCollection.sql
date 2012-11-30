create or replace function ar.getCollection(
    @collection integer,
    @pageSize integer,
    @pageNumber integer)
returns xml
begin
    declare @result xml;
    declare @tableId integer;
    
    for lloop as ccur cursor for
    select tableName as c_tableName,
           whereClause as c_whereClause
      from ar.collectionTable  
     where collection = @collection
    do
    
        set @tableId = (select st.table_id
                          from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                         where st.table_name =  substr(c_tableName, locate(c_tableName,'.') +1)
                           and su.user_name =  left(c_tableName, locate(c_tableName,'.') -1));
        
        set @result = xmlconcat(@result, ar.getTable(c_tableName, @tableId, @pageSize, @pageNumber, 'id', c_whereClause));
    
    end for;
    
    for lloop2 as ccur2 cursor for
    select collection as c_collection
      from ar.collectionCollection
     where parentCollection = @collection
    do
        set @result = xmlconcat(@result, ar.getCollection(c_collection, @pageSize, @pageNumber));
    
    end for;
    
    return @result;
end
;