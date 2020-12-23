create or replace procedure ar.xidById(
    @fkColumn STRING,
    @id STRING,
    @idName STRING default 'id'
)
begin
    declare @result GUID;
    declare @sql STRING;
    declare @entity STRING;
    declare @entityType STRING;

    if util.isGUID(@id) = 1 then
        select @id as xid;
        return;
    end if;

    set @entity = (
        select top 1 entityName
        from #fk
        where foreignColumn = @fkColumn
    );

    if @entity is null then
        select cast(null as GUID) as xid;
        return;
    end if;

    select FKDataSource,
        FKType
    into @entity, @entityType
    from ch.dataSource
    where entity = @entity
        and FKDataSource is not null;

    if @entityType is null then
        set @entityType = (
            select entityType
            from ar.entityIdAndType(@entity,'table')
        );
    end if;

    set @entity = ar.parseEntity(@entity);

    set @sql = string(
        'set @result = (select xid from ',
        @entity, if @entityType = 'sp' then '()' endif,
        ' where [', @idName, '] = ''',  @id, ''')'
    );

    execute immediate @sql;

    select @result as xid;

exception
    when others then

    select cast(null as GUID) as xid;

end
;
