create or replace procedure ar.xidById(
    @fkColumn STRING,
    @id STRING,
    @idName STRING default 'id'
)
begin
    declare @result uniqueidentifier;
    declare @sql long varchar;
    declare @entity long varchar;
    declare @entityType long varchar;

    if util.isGUID(@id) = 1 then
        select @id as xid;
        return;
    end if;

    set @entity = (select top 1 entityName from #fk where foreignColumn = @fkColumn);

    if @entity is null then
        select cast(null as uniqueidentifier) as xid;
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

    set @sql = 'set @result = (select xid from ' +
                @entity + if @entityType = 'sp' then '()' else '' endif +
                ' where [' + @idName +'] = ''' + @id +''')';

    --message 'ar.xidById @sql = ', @sql;

    execute immediate @sql;

    select @result as xid;

    exception
        when others then
            --message 'ar.xidById error = ',errormsg();
            return null;
end;
