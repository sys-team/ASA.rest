create or replace function ar.get(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id')
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
    declare @sql long varchar;
    declare @rawData xml;
    
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
    
    -- sql
    set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
               ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
               ' * ';
    
    if @entityType = 'table' then
                       
        set @sql = @sql +
                   'from [' + left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) + ']' +
                   if (select count(*) from #variable where name <> 'url' and name not like '%:') <> 0
                   then ' where ' +  (select list('[' + name +']='''+value+'''', ' and ') from #variable where name <> 'url' and name not like '%:')
                   else '' endif +
                   ' order by '+ @orderBy + ' desc for xml raw, elements';
    
    elseif @entityType = 'sp' then
    
        set @sql = @sql +
                   'from [' + left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) + ']' +
                   ' (' +
                   (select list('['+  name +']='''+value+'''')
                      from #variable
                     where name in (select parm_name from sys.sysprocparm where parm_mode_in = 'Y' and proc_id = @entityId)
                       and name <> 'url'
                       and name not like '%:') +
                   ') ' +
                   if (select count(*)
                         from #variable
                        where name not in (select parm_name from sys.sysprocparm where parm_mode_in = 'Y' and proc_id = @entityId)
                          and name <> 'url'
                          and name not like '%:') <> 0
                   then ' where ' +
                   (select list('[' + name +']='''+value+'''', ' and ')
                      from #variable
                     where name not in (select parm_name from sys.sysprocparm where parm_mode_in = 'Y' and proc_id = @entityId)
                       and name <> 'url'
                       and name not like '%:')
                   else '' endif +
                   ' order by '+ @orderBy + ' desc for xml raw, elements';     

    end if;
    
    --message 'ar.rest @sql for @rawData = ', @sql;
    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql;
    
    set  @sql = 'select xmlagg(xmlelement(''row'', xmlattributes(''' + @entity + ''' as "name"' +
                    ', id as "id"' +
                    ', xid as "xid"' +' ),' +
                    '(select xmlagg(xmlelement(''value'', ' +
                    'xmlattributes(name as "name") , value)) ' +
                    'from openxml(r ,''/row/*'') '+
                    'with ( name long varchar ''@mp:localname'', value long varchar ''.'')' +
                    ' where name not in (''id'', ''xid'') '+
                    ')' + 
                    ')) from ' +
            '(select r, id, xid '+
            ' from openxml(xmlelement(''root'',@rawData), ''/root/row'') ' +
            ' with(r xml ''@mp:xmltext'', id long varchar ''id'', xid long varchar ''xid'')) as t';
    
    --message 'ar.rest @sql = ', @sql;
    set @sql = 'set @response = (' + @sql +')';
    
    execute immediate @sql;
    
    return @response;
    

end
;