create or replace function ar.get(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id'),
    @columns long varchar default http_variable('columns:')
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @entity long varchar;
    declare @code long varchar;
    declare @id long varchar;
    declare @recordId bigint;
    declare @recordXid uniqueidentifier;
    
    declare local temporary table #fk(entityName long varchar,
                                  primaryColumn long varchar,
                                  foreignColumn long varchar);
                                            
    
    -- url elements
    select entity,
           id
      into @entity, @id
      from openstring(value @url)
           with (serv long varchar, entity long varchar, id long varchar)
           option(delimited by '/') as t;
    
    if @entity is null then
        set @response = xmlelement('response', xmlelement('error','Entity requered'));
        return @response;
    end if;   
           
    -- parms
    if @id is not null then
        if isnumeric(@id) = 1 then
            set @recordId = cast(@id as bigint);
            
            insert into #variable with auto name
            select 'id' as name,
                   cast(@recordId as long varchar) as value;
        else
            set @recordXid = util.strtoxid(@id);
            
            insert into #variable with auto name
            select 'xid' as name,
                   cast(@recordXId as long varchar) as value
             where @recordXid is not null;
            
        end if;        
    end if;
    
    if @entityId is null then
        raiserror 55555 'Entity %1! not found', @entity;
    end if;
    
    insert into #fk with auto name
    select entityName,
           primaryColumn,
           foreignColumn
      from ar.fkList(@entityId)
     where primaryColumn = 'id'
       and ar.isColumn(entityName, 'id') = 1
       and ar.isColumn(entityName, 'xid') = 1;
       
    -- sordgoods!!
    delete from #fk
     where entityName in (select entityName
                            from #fk
                           group by entityName
                          having count(distinct primaryColumn) <>1);
        
    -- message 'ar.get @entityType = ', @entityType;
    if @entityType = 'table' then
                       
        set @response = ar.getTable(@entity, @entityId, @pageSize, @pageNumber, @orderBy, null, null, @columns);
        
    elseif @entityType = 'collection' then
    
        set @response = ar.getCollection(@entityId, @pageSize, @pageNumber);
    
    elseif @entityType = 'sp' then
    
        set @response = ar.getSp(@entity, @entityId, @pageSize, @pageNumber, @orderBy, null, @columns);   

    end if;
    
    return @response;

end
;