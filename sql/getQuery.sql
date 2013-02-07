create or replace function ar.getQuery(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id'),
    @columns long varchar default http_variable('columns:'),
    @orderDir long varchar default http_variable('order-dir:')
)
returns xml
begin
    declare @result xml;
    declare @firstEntity long varchar;
    declare @secondEntity long varchar;
    declare @firstEntityId integer;
    declare @secondEntityId integer;
    
    
    declare local temporary table #fk1(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn long varchar);
                                      
    declare local temporary table #fk2(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn long varchar);
                                      
                                      
    -- parse url
    select firstEntity,
           secondEntity
      into @firstEntity, @id, @parentEntity
      from openstring(value @url)
           with (serv long varchar, entity long varchar, id long varchar, parentEntity long varchar)
           option(delimited by '/') as t;
    
    insert into #fk with auto name
    select entityName,
           primaryColumn,
           foreignColumn
      from ar.fkList(@entityId)
     /*where primaryColumn = 'id'
       and ar.isColumn(entityName, 'id') = 1
       and ar.isColumn(entityName, 'xid') = 1 */;
       
    
    
    
    return @result;
end
;