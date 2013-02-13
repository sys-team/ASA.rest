create or replace function ar.getQuery(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id'),
    @columns long varchar default http_variable('columns:'),
    @orderDir long varchar default http_variable('order-dir:'),
    @distinct long varchar default http_variable('distinct:')
)
returns xml
begin
    declare @result xml;
    declare @rawData xml;
    declare @entity long varchar;
    declare @entityId integer;
    declare @entityAlias long varchar;
    declare @entityType long varchar;
    declare @prevName long varchar;
    declare @prevEntityId integer;
    declare @prevAlias long varchar;
    declare @prevParsedName long varchar;
    declare @sql long varchar;
    declare @from long varchar;
    declare @where long varchar;
    declare @where2 long varchar;
    declare @extra long varchar;
    declare @error long varchar;
    declare @i integer;
    declare @pos integer;
    declare @currentEntity long varchar;
    
    declare local temporary table #entity(
        id integer default autoincrement,
        entityId integer,
        entityType long varchar,
        name long varchar,
        alias long varchar,
        parsedName long varchar,
        rawPredicate long varchar
    );
    
    declare local temporary table #predicate(
        entityId integer,
        predicate long varchar,
        predicateColumn long varchar
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
           alias = 't' + cast(id as varchar(24))
      from #entity outer apply (select entityId, entityType from ar.entityIdAndType(name)) as l;
      
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
    
    -- predicate parsing  
    call ar.parsePredicate();
    
    --set @result = (select * from #predicate for xml raw, elements);
    --return @result;
       
    delete from #variable
     where name in ('id','xid');
    
    -- last entity
    select top 1
           name,
           entityId,
           alias,
           entityType
      into @entity, @entityId, @entityAlias, @entityType
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
    
    set @columns = ar.parseColumns(@entityId, @columns, @entityAlias, @entityType);
    
    if exists(select *
                from ar.entityIdAndType('dbo.extra')
               where entityId is not null) and ar.isColumn(@entity, 'id') = 1 then
       
        set @extra = '(select xmlagg(xmlelement(''extra'', xmlattributes(et.code as "name"), e.value)) '+
                     'from dbo.extra e join dbo.etype et on e.etype = et.id ' +
                     'where e.record_id = ' + @entityAlias + '.id '+
                     'and et.table_name = ''' + substr(@entity, locate(@entity,'.') +1) + ''')' +
                     'as [___extras]';
          
    end if;
    
    
    set @sql = 'select ' + if @distinct = 'yes' then 'distinct ' else '' endif +
               ' top ' + cast(@pageSize as varchar(64)) + ' ' +
               ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
               ' ' + @columns +
               if @extra is not null then ',' + @extra else '' endif + ' ';
               
    for lloop as ccur cursor for
    select entityId as c_entityId,
           entityType as c_entityType,
           name as c_name,
           alias as c_alias,
           parsedName as c_parsedName,
           id as c_id
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

        
        end if;
        
        set @prevEntityId = c_entityId;
        set @prevName = c_name;
        set @prevAlias = c_alias;
        set @prevParsedName = c_parsedName;
    
    end for;
    
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
                    from (select @where as d union select @where2) as t
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