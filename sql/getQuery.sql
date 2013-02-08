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
    declare @rawData xml;
    declare @firstEntity long varchar;
    declare @secondEntity long varchar;
    declare @firstEntityId integer;
    declare @secondEntityId integer;
    declare @sql long varchar;
    declare @from long varchar;
    declare @where long varchar;
    declare @tmp long varchar;
    
    declare local temporary table #fk(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn long varchar);
                                      
    declare local temporary table #fk1(entityName long varchar,
                                      primaryColumn long varchar,
                                      foreignColumn long varchar);
                                      
                                      
    -- parse url
    select firstEntity,
           secondEntity
      into @firstEntity, @secondEntity
      from openstring(value @url)
           with (serv long varchar, firstEntity long varchar, id long varchar, secondEntity long varchar)
           option(delimited by '/') as t;
           
    select entityId
      into @firstEntityId
      from ar.entityIdAndType(@firstEntity);

    select entityId
      into @secondEntityId
      from ar.entityIdAndType(@secondEntity);
        
    insert into #fk with auto name
    select entityName,
           primaryColumn,
           foreignColumn
      from ar.fkList(@secondEntityId);

    insert into #fk1 with auto name
    select entityName,
           primaryColumn,
           foreignColumn
      from ar.fkList(@firstEntityId);
     
    -- order by
    if ar.isColumn(@secondEntity, @orderBy) = 0 then
        set @orderBy = null;
    end if;
    
    if @orderDir is null then
        set @orderDir = 'desc';
    end if;
    
    -- columns
    if @columns is null then
        set @columns = '*';
    end if;
    
    set @columns = ar.parseColumns(@secondEntityId, @columns, 'scnd');
       
    set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
           ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
           ' ' + @columns + ' ';
    
    set @from = ' from ' +
                coalesce((select top 1
                                 ar.parseEntity(@firstEntity) + ' as frst join ' +
                                 ar.parseEntity(@secondEntity) + ' as scnd on ' +
                                 'frst.' + primaryColumn + '=scnd.' + foreignColumn
                            from #fk
                           where entityName = @firstEntity),
                         (select top 1
                                 ar.parseEntity(@firstEntity) + ' as frst join ' +
                                 ar.parseEntity(@secondEntity) + ' as scnd on ' +
                                 'frst.' + foreignColumn + '=scnd.' + primaryColumn
                            from #fk1
                           where entityName = @secondEntity),
                          ar.parseEntity(@firstEntity) + ' as frst, ' + ar.parseEntity(@secondEntity) +' as scnd');
    
    --message 'ar.getQuery @from = ', @from;
    
    set @where = (select list('frst.[' + name +'] ' + operator + ' ' + value, ' and ')
                    from #variable
                   where name <> 'url'
                     and name not like '%:'
                     and ar.isColumn(@firstEntity, name) = 1);
                     
    set @tmp =   (select list('scnd.[' + name +'] ' + operator + ' ' + value, ' and ')
                    from #variable
                   where name <> 'url'
                     and name not like '%:'
                     and ar.isColumn(@secondEntity, name) = 1);
                     
    if length(@where) <> 0 or length(@tmp) <> 0 then
        set @where =' where ' + @where + if length(@where) <> 0 and length(@tmp) <> 0 then ' and ' else '' endif + @tmp;
    end if;
    
    --message 'ar.getQuery @where = ', @where;
    
    set @sql = @sql + @from + @where +
               if @orderBy is not null then ' order by scnd.'+ @orderBy + ' ' + @orderDir else '' endif +
               ' for xml raw, elements';
               
    --message 'sr.getQuery @sql = ', @sql;

    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql;

    set @result = ar.processRawData(@secondEntity, @secondEntityId, 'table', @rawData);    
    
    return @result;
end
;