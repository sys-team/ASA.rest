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
    declare @fkId integer;
    declare @updateSp long varchar;
    
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
          from ar.fkList(@entityId)
         where primaryColumn = 'id';
         
        for lloop as ccur cursor for
        select v.value as c_value,
               v.name as c_name,
               f.entityName as c_entityName               
          from #variable v join #fk f on v.name = f.foreignColumn
         where util.strtoxid(v.value) is not null 
        do
        
            set @sql = 'set @fkId = (' +
                       'select id from ' + c_entityName + ' where xid = ''' + c_value +''')';
            
            execute immediate @sql;
            
            update #variable
               set value = @fkId
             where name = c_name;
        
        end for
          
    end if;
    
    if @recordId is not null then
        insert into #variable with auto name
        select '@id' as name,
               @recordId as value;
    end if;
               
    -- sp update
    set @updateSp = (select top 1
                            u.user_name + '.' + p.proc_name
                       from sys.sysprocedure p join sys.sysuserperm u on p.creator = u.user_id
                      where u.user_name =  left(@entity, locate(@entity,'.') -1)
                        and locate(p.proc_name, substr(@entity, locate(@entity,'.') +1)+'_')=1
                        and not exists(select *
                                         from sys.sysprocparm
                                        where proc_id = p.proc_id
                                          and parm_mode_in = 'Y'
                                          and [default] is null
                                          and parm_name not in (select name from #variable)));
                                          
    if @updateSp is not null then
    
    
        set @sql = 'call ' + @updateSp + '(' +
                    (select list(name + '=''' + value +'''')
                       from #variable
                      where ar.isColumn(@updateSp, name, 1) = 1)
                    + ')';
                    
        message 'ar.put sp sql = ', @sql;
        
        execute immediate @sql;
    
    
    else
        set @sql = 'insert into [' + left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) +'] '+
                   ' on existing update with auto name '+
                   ' select ' +
                   (select list(''''+value+''' as [' + name + ']')
                      from #variable
                     where name <> 'url'
                       and name not like '%:'
                       and ar.isColumn(@entity, name) = 1) +
                    + if (select count(*)
                            from #variable
                           where name <> 'url'
                             and name not like '%:') <> 0  and not exists (select * from #variable where name = 'id') then ',' else '' endif
                    + if not exists (select * from #variable where name = 'id') then
                        if @recordId is null then ' null' else ' ''' + cast(@recordId as varchar(24)) + '''' end if + ' as id '
                      else '' endif;
                    
        message 'ar.put @sql = ', @sql;
                    
        execute immediate @sql;
        
        set @recordId = isnull(@recordId, @@identity);
    end if;
    
    delete from #variable;
    
    insert into #variable with auto name
    select 'id' as name,
            @recordId as value;
                
    set @response = ar.getTable(@entity,@entityId,1,1);

    return @response;
    
end
;