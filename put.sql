create or replace function ar.put(
    @url long varchar
)
returns xml
begin
    declare @response xml;
    declare @code long varchar;
    declare @sql long varchar;
    declare @entity long varchar;
    declare @id long varchar;
    declare @recordId bigint;
    declare @recordXid uniqueidentifier;
    declare @varName long varchar;
    declare @varValue long varchar;
    
    declare local temporary table #attributes(attribute long varchar,
                                              value long varchar);
    
    set @code = replace(http_header('Authorization'), 'Bearer ', '');
   
    -- url elements
    select entity,
           id
      into @entity, @id
      from openstring(value @url)
           with (entity long varchar, id long varchar)
           option(delimited by '/') as t;
           
    -- Authorization
    /*
    if ar.authorize(@code, @entity) <> 1 then
        set @response = xmlelement('response', xmlelement('error','Not autorized'));
        return @response;
    end if; */
           
    if @entity is null then
        set @response = xmlelement('response', xmlelement('error','Entity requered'));
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
    
    --  http variables
    set @varName = next_http_variable(null);
    
    while @varName is not null loop
        set @varValue = http_variable(@varName);
        
        if @varName not like '%:' and @varName not in ('url') then
            insert into #attributes with auto name
            select @varName as attribute,
                   @varValue as value;
        end if;

        set @varName = next_http_variable(@varName);
        
    end loop;
    
    if @recordXid is not null then
        set @sql = 'set @recordId = (select id from [' + left(@entity, locate(@entity,'.') -1) + '].[' +
                    substr(@entity, locate(@entity,'.') +1) +'] where xid = ''' + @recordXid + ''')';
        execute immediate @sql;
    end if;
    
    set @sql = 'insert into [' + left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) +'] '+
               ' on existing update with auto name '+
               ' select ' +
               (select list(''''+value+''' as [' + attribute + ']')
                  from #attribute) +
                + if @recordId is null then ' , null' else ', ' + cast(@recordId as varchar(24)) end if + ' as id ';
                
    execute immediate @sql;
    
    

    
    
    return @response;
end
;