create or replace function ar.columnDatatype(
    @entityId integer,
    @columnName long varchar,
    @entityType long varchar default 'table'
)
returns long varchar
begin
    declare @result long varchar;

    case @entityType
        when 'table' then
            set @result = (select top (1)
                                coalesce(u.type_name, d.domain_name)
                             from sys.syscolumn c join sys.sysdomain d on c.domain_id = d.domain_id
                                                  left outer join sys.sysusertype u on c.user_type  = u.type_id
                            where c.table_id = @entityId
                              and c.column_name = @columnName);
        when 'sp' then
            set @result = (select top(1)
                                d.domain_name
                             from sys.sysprocparm p join sys.sysdomain d on p.domain_id = d.domain_id
                            where p.proc_id = @entityId
                              and p.parm_name = @columnName
                              and p.parm_mode_out = 'Y');
    end case;

    set @result = util.dataTypeName(@result);
    
    if @result is null then
        set @result = 'expression';
    end if;

    return @result;

end
;
