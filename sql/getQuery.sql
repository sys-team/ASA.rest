create or replace function ar.getQuery(
    @url STRING,
    @pageSize integer default coalesce(nullif(http_header('page-size'),''), http_variable('page-size:'),10),
    @pageNumber integer default coalesce(nullif(http_header('page-number'),''), http_variable('page-number:'),1),
    @orderBy STRING default coalesce(nullif(http_header('order-by'),''),http_variable('order-by:'),'id'),
    @columns STRING default coalesce(nullif(http_header('columns'),''),http_variable('columns:')),
    @orderDir STRING default coalesce(nullif(http_header('order-dir'),''),http_variable('order-dir:')),
    @distinct STRING default coalesce(nullif(http_header('distinct'),''),http_variable('distinct:')),
    @longValues STRING default coalesce(nullif(http_header('long-values'),''),http_variable('long-values:')),
    @showNulls STRING default coalesce(nullif(http_header('show-nulls'),''),http_variable('show-nulls:')),
    @ETag STRING default util.HTTPVariableOrHeader ('if-none-match')
)
returns xml
begin
    declare @result xml;
    declare @rawData xml;
    declare @id integer;
    declare @entity STRING;
    declare @parsedName STRING;
    declare @entityId integer;
    declare @entityAlias STRING;
    declare @entityType STRING;
    declare @prevName STRING;
    declare @prevEntityId integer;
    declare @prevAlias STRING;
    declare @prevParsedName STRING;
    declare @prevDirection STRING;
    declare @sql STRING;
    declare @from STRING;
    declare @where STRING;
    declare @where2 STRING;
    declare @whereJoin STRING;  
    declare @extra STRING;
    declare @error STRING;
    declare @i integer;
    declare @pos integer;
    declare @currentEntity STRING;
    declare @direction STRING;
    declare @spWithNoResultSet integer;
    declare @isLateral integer;

    declare local temporary table #entity(
        id integer default autoincrement,
        entityId integer,
        entityType STRING,
        name STRING,
        alias STRING,
        parsedName STRING,
        rawPredicate STRING,
        rawPermPredicate STRING
    );
    
    declare local temporary table #predicate(
        entityId integer,
        predicate STRING,
        predicateColumn STRING
    );
    
    declare local temporary table #permPredicate(
        entityId integer,
        predicate STRING,
        predicateColumn STRING
    );
    
    declare local temporary table #joins(
        parent integer,
        child integer,
        parentColumn STRING,
        childColumn STRING
    );

    declare local temporary table #fk(
        entityName STRING,
        primaryColumn STRING,
        foreignColumn STRING
    );
                                      
    declare local temporary table #fk1(
        entityName STRING,
        primaryColumn STRING,
        foreignColumn STRING
    );

    --call ar.parseVariables();
    
    -- parse url
    set @url = substr(@url, locate(@url,'/') +1);

    set @pos = locate(@url,'/');
    set @i = 1;
    while @pos <> 0 loop
        if mod(@i,2) = 0 then
            set @url = left(@url, @pos - 1) + '~' + substr(@url, @pos + 1);
        end if;
        
        set @i = @i + 1;
        set @pos = locate(@url, '/', @pos+1);
    end loop;

    insert into #entity with auto name
    select name,
           rawPredicate
      from openstring(value @url)
           with (name STRING, rawPredicate STRING)
           option(delimited by '/' row delimited by '~') as t
     where name like '%.%';
        
    -- data sources    
    update #entity
       set name = ds.dataSource,
           entityType = ds.type
      from #entity e join ch.dataSource ds on e.name = ds.entity
     where ds.dataSource is not null;

    update #entity
       set entityId = l.entityId,
           entityType = isnull(#entity.entityType, l.entityType),
           parsedName = ar.parseEntity(name),
           alias = 't' + cast(id as varchar(24)),
           rawPermPredicate = if ar.entityPermission(regexp_substr(#entity.name, '^[^\.]+'),
                                                     regexp_substr(#entity.name,'(?<=\.).+')) = 1 then 'R' else null endif
      from #entity outer apply (select entityId, entityType from ar.entityIdAndType(name, #entity.entityType)) as l;
      
    -- error
    set @error = (select list(name)
                    from #entity
                   where entityId is null);
                   
    if @error <> '' then
        raiserror 55555 'Entity %1! not found', @error;
        return;
    end if;
      
    --set @result = (select * from #entity for xml raw, elements);
    --return @result;
    --message 'ar.getQuery @roles = ', @roles;
    
    -- predicate parsing  
    call ar.parsePredicate();
    
    --set @result = (select * from #predicate for xml raw, elements);
    --set @result = @result + (select * from #joins for xml raw, elements);
    --return @result;
    
    -- last entity
    select top 1
           id,
           name,
           entityId,
           alias,
           entityType,
           ar.parseEntity(name)
      into @id, @entity, @entityId, @entityAlias, @entityType, @parsedName
      from #entity
     order by id desc;
     
    -- order by
    if ar.isColumn(@entity, @orderBy) = 0 then
        set @orderBy = null;
    end if;
    
    if @orderDir is null then
        set @orderDir = 'desc';
    end if;
    
    if @ETag is not null then
        set @orderBy = 'left(ts,23) asc, id asc';
        set @orderDir = '';
    end if;
    
    -- columns
    if @columns is null then
        set @columns = '*';
    end if;
    
    -- If one record by key then @longValues = yes
    if exists (
            select * from (
                select name
                    from #variable
                union select predicateColumn
                    from #predicate
                    where entityId = @id
            ) as t
            where name in (
                select top (1) column_name
                    from ar.pkList('', @entityId)
                union select 'xid'
            )
    ) then
        set @longValues = 'yes';
    end if;
    
    set @columns = ar.parseColumns(
        @entityId, @columns, @entityAlias, @entityType, if @longValues = 'yes' then 1 else 0 endif
    );
    
    --
    if isnull(@columns, '') = '' and @entityType = 'sp' then
        set @spWithNoResultSet = 1;
    else
        set @spWithNoResultSet = 0;
    end if;
    
    if @spWithNoResultSet = 1 then
    
        set @sql = 'call ' + @parsedName + '(' +
                        (select list(d)
                          from (
                              select '[' + name + ']=' + value as d
                                  from #variable
                                  where ar.isColumn(@entity, name, 1, 'sp') = 1
                              union select predicate
                                  from #predicate
                                  where entityId = @id
                                      and predicate like '%=%'
                                      and ar.isColumn(@entity, predicateColumn, 1, 'sp') = 1) as t
                      ) + ')';
                      
    else
    
        if exists(select *
                    from ar.entityIdAndType('dbo.extra')
                   where entityId is not null)
          and ar.isColumn(@entity, 'id') = 1
          and ar.columnDatatype(@entityId, 'id', @entityType) in  ('integer','bigint') then

            set @extra = '(select xmlagg(xmlelement(''extra'', xmlattributes(et.code as "name"), e.value)) '+
                         'from dbo.extra e join dbo.etype et on e.etype = et.id ' +
                         'where e.record_id = ' + @entityAlias + '.id '+
                         'and et.table_name = ''' + substr(@entity, locate(@entity,'.') +1) + ''')' +
                         'as [___extras]';
              
        end if;
        
        -- root entity permission check
        if not exists(select *
                        from #entity
                       where id = 1
                         and rawPermPredicate is not null) and @isDba = 0 then
                        
            raiserror 55555 'Permission denied on entity %1!', @entity;
            return;
        end if;
                   
        for lloop as ccur cursor for
        select entityId as c_entityId,
               entityType as c_entityType,
               name as c_name,
               alias as c_alias,
               parsedName as c_parsedName,
               id as c_id,
               rawPermPredicate as c_rawPermPredicate
          from #entity
          order by id
        do
            case c_entityType
                when 'table' then
                    set @currentEntity = c_parsedName + ' as ' + c_alias;
                when 'sp' then

                    select
                        string (
                            c_parsedName, '(',
                            list(d),
                            ') as ', c_alias
                        ),
                        max(isLateral)
                    into @currentEntity, @isLateral
                    from (
                        select '[' + name + ']=' + value as d, 0 as isLateral
                            from #variable
                            where ar.isColumn(c_name, name, 1, 'sp') = 1
                        union select predicate, 0
                            from #predicate
                            where entityId = c_id
                                and predicate like '%=%'
                                and ar.isColumn(c_name, predicateColumn, 1, 'sp') = 1
                        union select
                            '[' + foreignColumn + ']=' + @prevAlias + '.[' + primaryColumn + ']',
                            1
                        from ar.fkList(c_entityId, c_name) fk
                        where entityName in (
                            @prevName,
                            ch.entityStorage(@prevName)
                        ) and ar.isColumn(c_name, foreignColumn, 1, 'sp') = 1
                    ) as t;

            end case;
        
            if c_id = 1 then
                set @from = @currentEntity;
                
                insert into #fk with auto name
                select entityName,
                       primaryColumn,
                       foreignColumn
                  from ar.fkList(c_entityId, c_name);
            else
            
                delete from #fk;
                delete from #fk1;
                
                insert into #fk with auto name
                select entityName,
                       primaryColumn,
                       foreignColumn
                  from ar.fkList(c_entityId, c_name);
                  
                insert into #fk1 with auto name
                select entityName,
                       primaryColumn,
                       foreignColumn
                  from ar.fkList(@prevEntityId, c_name);

                set @from  = @from + coalesce(
                    (select top 1
                            ' join ' +
                            @currentEntity + ' on ' +
                            @prevAlias + '.[' + primaryColumn + '] = ' + c_alias + '.[' + foreignColumn + ']'
                        from #fk
                        where entityName in (
                            @prevName,
                            ch.entityStorage(@prevName)
                        ) and ar.isColumn (c_name, foreignColumn) = 1
                    ),
                    (select top 1
                            ' join ' +
                            @currentEntity + ' on ' +
                            @prevAlias + '.[' + foreignColumn + ']=' + c_alias + '.[' + primaryColumn + ']'
                        from #fk1
                        where entityName = c_name
                    ),
                    ', ' + if @isLateral = 1 then 'lateral (' + replace(@currentEntity,') as',')) as') else @currentEntity endif
                );

                -- auto distinct and direction
                if exists (select *
                             from #fk1
                            where entityName = c_name) then
                            
                    set @distinct = 'yes';
                    set @direction = 'up';
                    
                elseif exists (select *
                             from #fk
                            where entityName = @prevName) then
                        
                    set @direction = 'down';
                else
                    set @direction = 'cross';
                end if;
                
                -- message 'ar.getQuery @direction = ', @direction;
                -- pemission check by direction
                if @isDba = 0 then
                    if @direction in ('cross') and c_rawPermPredicate is null then
                   
                        raiserror 55555 'Permission denied on cross join with %1!', c_name;
                        return;
                        
                    elseif @direction in ('down') and c_rawPermPredicate is null and @prevDirection <> 'down' then
                    
                        raiserror 55555 'Permission denied on down join with %1!', c_name;
                        return;
                        
                    end if;
                end if;
                
            end if;
            
            set @prevEntityId = c_entityId;
            set @prevName = c_name;
            set @prevAlias = c_alias;
            set @prevParsedName = c_parsedName;
            set @prevDirection = @direction;
        
        end for;
        
        set @sql =
            'select ' + if @distinct = 'yes' then 'distinct ' else '' endif +
            ' top ' + cast(@pageSize as varchar(64)) + ' ' +
            ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
            @columns  +
            if @extra is not null then ',' + @extra else '' endif + ' '
        ;
        
        set @whereJoin = (
            select list(p.alias +'.[' + j.parentColumn + '] = ' + c.alias + '.[' + j.childColumn + ']', ' and ')
            from #joins j
                join #entity p on j.parent = p.id
                join #entity c on j.child = c.id
        );
        
        set @where = (
            select list(e.alias + '.[' + v.name + ']' + v.operator + ' ' + v.value, ' and ')
            from #variable v, #entity e
            where v.name <> 'url'
               and v.name not like '%:'
               and ar.isColumn(e.name, v.name) = 1
        );
        
        set @where2 = (
            select list(e.alias + '.' + p.predicate, ' and ')
            from #entity e join #predicate p on e.id = p.entityId
            where (p.predicate like '%=%'
                    or p.predicate like '%<%'
                    or p.predicate like '%>%'
                    or p.predicate like '%like%'
                )
                and ar.isColumn(e.name, p.predicateColumn) = 1
        );
        
        set @where = (
            select list(d, ' and ') as li
            from (
                select @whereJoin as d
                union select @where
                union select @where2
                union select string (
                    'ts >= ''', ar.tsFromETag(@ETag), '''',
                    ' and (id > ', ar.idFromETag(@ETag),
                    ' or ts >= ''', dateadd(ms,1,ar.tsFromETag(@ETag)), '''',
                    ')'
                ) where length(@ETag) > 3
            ) as t
            where isnull(d, '') <> ''
        );
        
        set @sql = @sql + 'from ' + @from + 
            if @where <> '' then ' where ' else '' endif + @where +
            if @orderBy is not null
               and (@ETag is not null or @distinct <> 'yes' or locate(@columns, '[' + @orderBy + ']') <> 0)
            then
                string (
                    ' order by ',
                    if @ETag is null then @entityAlias + '.' endif,
                    @orderBy, ' ', @orderDir
                )
            else '' endif +
            ' for xml raw, elements'
        ;
        
    end if;
    --message 'ar.getQuery @sql = ', @sql;
    
    update ar.log
       set sqlText = if sqlText is not null then sqlText + '; ' else '' endif + @sql
     where xid = @xid;
    
    if @spWithNoResultSet = 0 then
        set @sql = 'set @rawData = (' + @sql +')';
    end if;
    
    if @showNulls = 'yes' then
        set temporary option for_xml_null_treatment  = 'Empty';
    end if;
    
    execute immediate @sql;
    
    if @spWithNoResultSet = 1 then
        set @rowcount = @@rowcount;
    end if;
    
    if @showNulls = 'yes' then
        set temporary option for_xml_null_treatment  = 'Omit';
    end if;

    
    if @spWithNoResultSet = 0 then
        if not isnull(util.getUserOption ('ar.chestToRawData'), 'true') = 'false' then
            set @rawdata = ar.chestToRawData(@entity,@rawData)
        end if;
    
        set @result = ar.processRawData(@entity, @entityId, @entityType, @rawData);
    end if;
    
    return @result;
    
end;