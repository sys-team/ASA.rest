create or replace function ar.news(
    @url STRING,
    @domain STRING default http_variable('domain:'),
    @offset STRING default http_variable('offset:'),
    @pageSize integer default coalesce(nullif(http_header('page-size'),''), http_variable('page-size:'),10)
)
returns xml
begin
    declare @result xml;
    declare @ts datetime;
    declare @sql STRING;
    declare @entityType STRING;
    
    declare local temporary table
    #news(
        entity STRING,
        ts datetime,
        xid GUID
    );
    
    if @domain is null then
        set @domain = regexp_substr(@url,'(?<=/)[^/]+');
    end if;
        
    set @ts = isnull(util.tsFromOffset(@offset), today());
    
    for lloop as ccur cursor for
    select property as c_entity
      from ch.entityProperty
     where entity = @domain
    do
        set @entityType = (select entityType
                             from ar.entityIdAndType(c_entity));
    
        if @entityType is not null then
            set @sql = 'insert into #news with auto name ' +
                       'select top ' + cast(@pageSize as varchar(24)) + ' c_entity as entity, '+
                       'ts, xid from ' + ar.parseEntity(c_entity) +
                       if @entityType = 'sp' then '() ' else ' ' endif +
                       'where ts >= ''' + cast(@ts as varchar(24)) +''' ' +
                       'order by ts';
                      
            execute immediate @sql;
        end if;
    
    end for;
    
    for lloop2 as ccur2 cursor for
    select top @pageSize
           entity as c_entity,
           xid as c_xid
      from #news
     order by ts
    do
    
        set @result = xmlconcat(@result,
                                ar.getQuery(
                                            'get/' + c_entity +'/' + uuidtostr(c_xid),
                                            @pageSize,
                                            1,
                                            'ts',
                                            '*',
                                            'asc',
                                            'yes',
                                            'yes'));
    
    end for;
    
    set @newsNextOffset = coalesce((select top 1 start at (@pageSize + 1)
                                           util.offsetFromTs(ts)
                                      from #news
                                    order by ts),
                                   (select util.offsetFromTs(max(ts))
                                      from #news),
                                   util.offsetFromTs(@ts));
                                   
    --message 'ar.news @newsNextOffset = ', @newsNextOffset;
         
    return @result;
end
;