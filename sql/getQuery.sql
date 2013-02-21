create or replace function ar.getQuery(
    @url long varchar,
    @pageSize integer default coalesce(nullif(http_header('page-size'),''), http_variable('page-size:'),10),
    @pageNumber integer default coalesce(nullif(http_header('page-number'),''), http_variable('page-number:'),1),
    @orderBy long varchar default coalesce(nullif(http_header('order-by'),''),http_variable('order-by:'),'id'),
    @columns long varchar default coalesce(nullif(http_header('columns'),''),http_variable('columns:')),
    @orderDir long varchar default coalesce(nullif(http_header('order-dir'),''),http_variable('order-dir:')),
    @distinct long varchar default coalesce(nullif(http_header('distinct'),''),http_variable('distinct:')),
    @longValues long varchar default coalesce(nullif(http_header('long-values'),''),http_variable('long-values:'))    
)
returns xml
begin
    declare @result xml;
    declare @rawData xml;
    declare @id integer;
    declare @entity long varchar;
    declare @entityId integer;
    declare @entityAlias long varchar;
    declare @entityType long varchar;
    declare @prevName long varchar;
    declare @prevEntityId integer;
    declare @prevAlias long varchar;
    declare @prevParsedName long varchar;
    declare @prevDirection long varchar;
    declare @sql long varchar;
    declare @from long varchar;
    declare @where long varchar;
    declare @where2 long varchar;
    declare @whereJoin long varchar;  
    declare @extra long varchar;
    declare @error long varchar;
    declare @i integer;
    declare @pos integer;
    declare @currentEntity long varchar;
    declare @direction long varchar;
    
    declare local temporary table #entity(
        id integer default autoincrement,
        entityId integer,
        entityType long varchar,
        name long varchar,
        alias long varchar,
        parsedName long varchar,
        rawPredicate long varchar,
        rawPermPredicate long varchar
    );
    
    declare local temporary table #predicate(
        entityId integer,
        predicate long varchar,
        predicateColumn long varchar
    );
    
    declare local temporary table #permPredicate(
        entityId integer,
        predicate long varchar,
        predicateColumn long varchar
    );
    
    declare local temporary table #joins(
        parent integer,
        child integer,
        parentColumn long varchar,
        childColumn long varchar
    );

    declare local temporary table #fk(
        entityName long varchar,
        primaryColumn long varchar,
        foreignColumn long varchar
    );
                                      
    declare local temporary table #fk1(
        entityName long varchar,
        primaryColumn long varchar,
        foreignColumn long varchar
    );

    call ar.parseVariables();
    
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
           with (name long varchar, rawPredicate long varchar)
           option(delimited by '/' row delimited by '~') as t
     where name like '%.%';
        
    --set @result = (select * from #entity for xml raw, elements);
    --return @result;
      
    update #entity
       set entityId = l.entityId,
           entityType = l.entityType,
           parsedName = ar.parseEntity(name),
           alias = 't' + cast(id as varchar(24)),
           rawPermPredicate = roles.data
      from #entity outer apply (select entityId, entityType from ar.entityIdAndType(name)) as l
                   left outer join (select code,
                                           list(data, '&') as data
                                      from openxml(@roles,'/*:response/*:roles/*:role')
                                            with(code long varchar '*:code', data long varchar '*:data')
                                     group by code) as roles on roles.code = #entity.name;
      
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
           entityType
      into @id, @entity, @entityId, @entityAlias, @entityType
      from #entity
     order by id desc;
     
    -- order by
    if ar.isColumn(@entity, @orderBy) = 0 then
        set @orderBy = null;
    end if;
    
    if @orderDir is null then
        set @orderDir = 'desc';
    end if;
    
    -- columns
    if @columns is null then
        set @columns = '*';
    end if;
    
    -- If one record by key then @longValues = yes
    if exists(select *
                from (select name
                        from #variable
                       union
                      select predicateColumn
                        from #predicate
                       where entityId = @id) as t
              where name in (select top (1)
                                    column_name
                               from ar.pkList('', @entityId)
                              union
                             select 'xid')) then
                                                                  
        set @longValues = 'yes';
    end if;
    
    set @columns = ar.parseColumns(@entityId, @columns, @entityAlias, @entityType, if @longValues = 'yes' then 1 else 0 endif);
    
    if exists(select *
                from ar.entityIdAndType('dbo.extra')
               where entityId is not null) and ar.isColumn(@entity, 'id') = 1
      and ar.columnDatatype(@entityId, 'id') in  ('integer','bigint') then
       
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
                set @currentEntity = c_parsedName + '(' +
                                    (select list(d)
                                       from (select '[' + name + ']=' + value as d
                                               from #variable
                                              where ar.isColumn(c_name, name, 1) = 1
                                              union
                                             select predicate
                                               from #predicate
                                              where entityId = c_id
                                                and predicate like '%=%'
                                                and ar.isColumn(c_name, predicateColumn, 1) = 1) as t) + 
                                    ') as ' + c_alias;
        end case;
    
        if c_id = 1 then
            set @from = @currentEntity;
        else
        
            delete from #fk;
            delete from #fk1;
            
            insert into #fk with auto name
            select entityName,
                   primaryColumn,
                   foreignColumn
              from ar.fkList(c_entityId);
              
            insert into #fk1 with auto name
            select entityName,
                   primaryColumn,
                   foreignColumn
              from ar.fkList(@prevEntityId);
        
            set @from  = @from + 
                        coalesce((select top 1
                                         ' join ' +
                                         @currentEntity + ' on ' +
                                         @prevAlias + '.' + primaryColumn + '=' + c_alias + '.' + foreignColumn
                                    from #fk 
                                   where entityName = @prevName),
                                 (select top 1
                                         ' join ' +
                                         @currentEntity + ' on ' +
                                         @prevAlias + '.' + foreignColumn + '=' + c_alias + '.' + primaryColumn
                                    from #fk1
                                   where entityName = c_name),
                                  ', ' + @currentEntity );
                                  
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
    
    set @sql = 'select ' + if @distinct = 'yes' then 'distinct ' else '' endif +
               ' top ' + cast(@pageSize as varchar(64)) + ' ' +
               ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
               ' ' + @columns +
               if @extra is not null then ',' + @extra else '' endif + ' ';
               
    set @whereJoin = (select list(p.alias +'.[' + j.parentColumn + '] = ' + c.alias + '.[' + j.childColumn + ']', ' and ')
                        from #joins j join #entity p on j.parent = p.id
                                      join #entity c on j.child = c.id);
                                      
    set @where = (select list(e.alias + '.[' + v.name + ']' + v.operator + ' ' + v.value, ' and ')
                    from #variable v, #entity e
                   where v.name <> 'url'
                     and v.name not like '%:'
                     and ar.isColumn(e.name, v.name) = 1);
                     
    set @where2 = (select list(e.alias + '.' + p.predicate, ' and ')
                     from #entity e join #predicate p on e.id = p.entityId
                    where (p.predicate like '%=%'
                       or p.predicate like '%<%'
                       or p.predicate like '%>%')
                      and ar.isColumn(e.name, p.predicateColumn) = 1 );
                      
    set @where = (select list(d, ' and ') as li
                    from (select @whereJoin as d union select @where union select @where2) as t
                   where isnull(d, '') <> '');
                      
    set @sql = @sql + 'from ' + @from + 
               if @where <> '' then ' where ' else '' endif + @where +
               if @orderBy is not null then ' order by ' + @entityAlias + '.' + @orderBy + ' ' + @orderDir else '' endif +
               ' for xml raw, elements';
    
    --message 'ar.getQuery @sql = ', @sql;
    
    update ar.log
       set sqlText = @sql
     where xid = @xid;
    
    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql; 

    set @result = ar.processRawData(@entity, @entityId, @entityType, @rawData);    
    
    return @result;
end
;