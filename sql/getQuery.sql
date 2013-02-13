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
    declare @prevName long varchar;
    declare @prevEntityId integer;
    declare @prevAlias long varchar;
    declare @prevParsedName long varchar;
    declare @sql long varchar;
    declare @from long varchar;
    declare @where long varchar;
    declare @where2 long varchar;
    declare @error long varchar;
    declare @i integer;
    declare @pos integer;
    
    declare local temporary table #entity(
        id integer default autoincrement,
        entityId integer,
        name long varchar,
        alias long varchar,
        parsedName long varchar,
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
           predicate
      from openstring(value @url)
           with (name long varchar, predicate long varchar)
           option(delimited by '/' row delimited by '~') as t
     where name like '%.%';
      
    update #entity
       set entityId = l.entityId,
           parsedName = ar.parseEntity(name),
           alias = 'tab' + cast(id as varchar(24))
      from #entity outer apply (select entityId from ar.entityIdAndType(name,'table')) as l;
      
    -- predicate parsing  
    call ar.parsePredicate();
       
    delete from #variable
     where name in ('id','xid');
     
    -- error
    set @error = (select list(name)
                    from #entity
                   where entityId is null);
                   
    if @error <>'' then
        raiserror 55555 'Entity %1! not found', @error;
        return;
    end if;
    
    -- last entity
    select top 1
           name,
           entityId,
           alias
      into @entity, @entityId, @entityAlias
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
    
    set @columns = ar.parseColumns(@entityId, @columns, @entityAlias);
    
    
    set @sql = 'select ' + if @distinct = 'yes' then 'distinct ' else '' endif +
               ' top ' + cast(@pageSize as varchar(64)) + ' ' +
               ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
               ' ' + @columns + ' ';
               
    for lloop as ccur cursor for
    select entityId as c_entityId,
           name as c_name,
           alias as c_alias,
           parsedName as c_parsedName,
           id as c_id
      from #entity
      order by id
    do
    
        if c_id = 1 then
            set @from = c_parsedName + ' as ' + c_alias;
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
                                         c_parsedName + ' as ' + c_alias + ' on ' +
                                         @prevAlias + '.' + primaryColumn + '=' + c_alias + '.' + foreignColumn
                                    from #fk 
                                   where entityName = @prevName),
                                 (select top 1
                                         ' join ' +
                                         c_parsedName + ' as ' + c_alias + ' on ' +
                                         @prevAlias + '.' + foreignColumn + '=' + c_alias + '.' + primaryColumn
                                    from #fk1
                                   where entityName = c_name),
                                  ', ' + c_parsedName +' as ' + c_alias);

        
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
                     
    set @where2 = (select list(alias + '.' +predicate, ' and ')
                     from #entity
                    where predicate like '%=%'
                       or predicate like '%<%'
                       or predicate like '%>%');

    set @sql = @sql + 'from ' + @from
               + if @where <> '' or @where2 <> '' then ' where ' + @where else '' endif +
               if @where <> '' then ' and ' else '' endif + @where2 +
               if @orderBy is not null then ' order by ' + @entityAlias + '.' + @orderBy + ' ' + @orderDir else '' endif +
               ' for xml raw, elements';
    
    --message 'ar.getQuery @sql = ', @sql;
    
    update ar.log
       set sqlText = @sql
     where xid = @xid;
    
    set @sql = 'set @rawData = (' + @sql +')';
    
    execute immediate @sql; 

    set @result = ar.processRawData(@entity, @entityId, 'table', @rawData);    
    
    return @result;
end
;