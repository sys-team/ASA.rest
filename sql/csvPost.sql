create or replace function ar.csvPost(
    @url long varchar,
    @columns long varchar default coalesce(nullif(http_header('columns'),''),http_variable('columns:'))
)
returns xml
begin
    declare @result xml;
    declare @data long varchar;
    declare @entity long varchar;
    declare @entityId integer;
    declare @entityType long varchar;
    declare @parsedName long varchar;
    declare @sql long varchar;
    
    select entity
      into @entity 
      from openstring(value @url)
           with(sevice long varchar, entity long varchar)
           option(delimited by '/') as t;
           
    select entityId,
           entityType
      into @entityId, @entityType
      from ar.entityIdAndType(@entity);
      
    if @entityId is null then
        raiserror 55555 'Entity %1! not found', @entity;
        return;
    end if;
    
    if @entityType <> 'table' then
        raiserror 55555 'Entity %1! not a table', @entity;
        return;
    end if;
    
    set @data = http_body();
    if isnull(@data, '') = '' then
        raiserror 55555 'No data posted', @entity;
        return;
    end if;
    
    set @columns = '[' + replace(@columns, ',', '],[') + ']';
    set @parsedName = ar.parseEntity(@entity);
    
    set @sql = 'insert into ' + @parsedName + ' (' + @columns + ') on existing update ' +
               'select * from openstring(value isnull(@data,'''')) '+
               'with(' +
               (select list('f'+ cast(rowid(t) as varchar(24))+' long varchar')
                  from openstring(value isnull(@columns,''))
                       with(v long varchar)
                       option( row delimited by '],[') as t) + ') ' +
               'option(delimited by '';'') as t';
               
    update ar.log
       set sqlText = @sql
     where xid = @xid;
     
    message 'ar.csvPost @data = ', @data;
    
    execute immediate @sql;   
    


    return @result;
end
;