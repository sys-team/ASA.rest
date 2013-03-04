create or replace function ar.isColumn(
    @entity long varchar,
    @columnName long varchar,
    @procMode integer default 0,
    @entityType long varchar default 'any')
returns integer
begin
    
    if exists(select *
                from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                                         join sys.sysprocparm p on p.proc_id = sp.proc_id
               where sp.proc_name =  substr(@entity, locate(@entity,'.') +1)
                 and su.user_name =  left(@entity, locate(@entity,'.') -1)
                 and p.parm_name = @columnName
                 and (p.parm_type = 0 and @procMode = 1
                  or p.parm_type in (1,4) and @procMode = 0)
                 and @entityType in ('sp', 'any'))
    or exists(select *
                from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                                     join sys.syscolumn c on c.table_id = st.table_id
               where st.table_name =  substr(@entity, locate(@entity,'.') +1)
                 and su.user_name =  left(@entity, locate(@entity,'.') -1)
                 and c.column_name = @columnName
                 and @entityType in ('table', 'any')) then
        return 1;
    end if;
    
    return 0;    
end
;