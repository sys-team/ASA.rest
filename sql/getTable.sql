create or replace function ar.getTable(
    @entityName long varchar,
    @entityId integer,
    @pageSize integer,
    @pageNumber integer,
    @orderBy long varchar default 'id',
    @collection integer default null,
    @restriction long varchar default null,
    @columns long varchar default '*',
    @orderDir long varchar default 'desc'
)
returns xml
begin
    declare @result xml;
    declare @rawData xml;
    declare @sql long varchar;
    declare @where long varchar;

    
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
                          
    -- order by
    if ar.isColumn(@entityName, @orderBy) = 0 then
        set @orderBy = null;
    end if;
    
    if @orderDir is null then
        set @orderDir = 'desc';
    end if;
    
    -- columns
    if @columns is null then
        set @columns = '*';
    end if;
    
    set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
           ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
           ' ' + @columns + ' ';
           
    if @collection is not null then
        set @where = @where +' xid in ('+ isnull((select nullif(list('''' + uuidtostr(elementXid) + ''''),'')
                                                    from ar.element
                                                    where collection = @collection
                                                      and tableName = @entityName),'null') + ') ';
    end if;
    
    if (select count(*) from #variable where name <> 'url' and name not like '%:') <> 0  then
        set @where = @where  +  if @where is not null then ' and ' else '' endif +
                     (select list('[' + name +']' + operator + ''''+value+'''', ' and ') from #variable where name <> 'url' and name not like '%:');
    end if;
    
    if @restriction is not null then
        set @where = @where  +  if @where is not null then ' and ' else '' endif +
                     ' id in (' + @restriction + ')';
    end if;
    
    set @sql = @sql +
           'from [' + left(@entityName, locate(@entityName,'.') -1) + '].[' + substr(@entityName, locate(@entityName,'.') +1) + ']' +
           if length(@where) <> 0 then ' where ' + @where else '' endif +
           if @orderBy is not null then ' order by '+ @orderBy + ' ' + @orderDir else '' endif +
           ' for xml raw, elements';
           
    --message 'ar.getTable @sql = ', @sql;
           
    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql;
    
    --message 'ar.getTable @rawData = ', @rawData;
    
    set @result = ar.processRawData(@entityName, @entityId, 'table', @rawData);
    
    return @result;
end
;