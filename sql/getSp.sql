create or replace function ar.getSp(
    @entityName long varchar,
    @entityId integer,
    @pageSize integer,
    @pageNumber integer,
    @orderBy long varchar default 'id',
    @whereClause long varchar default null,
    @columns long varchar default null
)
returns xml
begin
    declare @result xml;
    declare @sql long varchar;
    declare @rawData xml;
    
    set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
               ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
               ' ' + if @columns is not null then @columns else '*' endif + ' ';
    
    set @sql = @sql +
            'from [' + left(@entityName, locate(@entityName,'.') -1) + '].[' + substr(@entityName, locate(@entityName,'.') +1) + ']' +
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
            if ar.isColumn( @entityName,'id') = 1 then 'order by '+ @orderBy + ' desc' else '' endif  +
            ' for xml raw, elements';
            
    --message 'ar.rest @sql for @rawData = ', @sql;
    set @sql = 'set @rawData = (' + @sql +')';
 
    execute immediate @sql;

    set @result = ar.processRawData(@entityName, @entityId, 'sp', @rawData);
    
    return @result;
end
;