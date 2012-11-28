create or replace function ar.put(
    @url long varchar
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @sql long varchar;
    declare @entity long varchar;
    declare @id long varchar;
    declare @recordId bigint;
    declare @recordXid uniqueidentifier;
    declare @varName long varchar;
    declare @varValue long varchar;
    
    declare local temporary table #fk(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn liong varchar,
                                      value long varchar);
                                            
    -- url elements
    select entity,
           id
      into @entity, @id
      from openstring(value @url)
           with (serv long varchar, entity long varchar, id long varchar)
           option(delimited by '/') as t;
           
    if @entity is null then
        set @response = xmlelement('response', xmlelement('error','Entity required'));
        return @response;
    end if;
    
    -- parms
    if @id is not null then
        if isnumeric(@id) = 1 then
            set @recordId = cast(@id as bigint);
        elseif util.strtoxid(@id) is not null then
            set @recordXid = util.strtoxid(@id);
        end if;        
    end if;
    
    
    if @recordXid is not null then
        set @sql = 'set @recordId = (select id from [' + left(@entity, locate(@entity,'.') -1) + '].[' +
                    substr(@entity, locate(@entity,'.') +1) +'] where xid = ''' + @recordXid + ''')';
        execute immediate @sql;
    end if;
    
    -- fks
    if @entityType = 'table' then
        insert into #fk with auto name
        select entityName,
               primaryColumn,
               foreignColumn
          from ar.fkList(@entityId);
          
    end if;
    
    set @sql = 'insert into [' + left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) +'] '+
               ' on existing update with auto name '+
               ' select ' +
               (select list(''''+value+''' as [' + name + ']')
                  from #variable
                 where name <> 'url'
                   and name not like '%:') +
                + if (select count(*)
                        from #variable
                       where name <> 'url'
                         and name not like '%:') <> 0 then ',' else '' endif 
                + if @recordId is null then ' null' else ' ' + cast(@recordId as varchar(24)) end if + ' as id ';
                
    message 'ar.put @sql = ', @sql;
                
    execute immediate @sql;
    
    return @response;
    
end
;