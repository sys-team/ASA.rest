create or replace function ar.getTable(
    @entityName long varchar,
    @entityId integer,
    @pageSize integer,
    @pageNumber integer,
    @orderBy long varchar default 'id',
    @collection integer default null
)
returns xml
begin
    declare @result xml;
    declare @rawData xml;
    declare @sql long varchar;
    
    declare local temporary table #fk(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn long varchar);
    
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
    
    set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
           ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
           ' * ';
           
    set @sql = @sql +
           'from [' + left(@entityName, locate(@entityName,'.') -1) + '].[' + substr(@entityName, locate(@entityName,'.') +1) + ']' +
           if @collection is not null then
                'where xid in ('+ isnull((select nullif(list('''' + uuidtostr(elementXid) + ''''),'')
                                            from ar.element
                                           where collection = @collection
                                             and tableName = @entityName),'null') + ') '
           else
                if (select count(*) from #variable where name <> 'url' and name not like '%:') <> 0
                then ' where ' +  (select list('[' + name +']='''+value+'''', ' and ') from #variable where name <> 'url' and name not like '%:')
                else '' endif
           endif +
           ' order by '+ @orderBy + ' desc for xml raw, elements';
           
    --message 'ag.getTable @sql = ', @sql;
           
    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql;
    
    set @result = ar.processRawData(@entityName, @entityId, 'table', @rawData);
    
    return @result;
end
;