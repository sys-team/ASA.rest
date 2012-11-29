create or replace procedure ar.xidById(@fkColumn long varchar, @id long varchar)
begin
    declare @result uniqueidentifier;
    declare @sql long varchar;
    declare @entity long varchar;
    
    set @entity = (select top 1 entityName from #fk where foreignColumn = @fkColumn);
    
    if @entity is null then
        select cast(null as uniqueidentifier) as xid;
        return;
    end if;
    
    set @sql = 'set @result = (select xid from [' + 
                left(@entity, locate(@entity,'.') -1) + '].[' + substr(@entity, locate(@entity,'.') +1) + ']' +
                ' where id = ''' + @id +''')';
    execute immediate @sql;
    
    select @result as xid;
    
end
;