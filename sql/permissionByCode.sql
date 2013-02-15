create or replace procedure ar.permissionByCode(@code long varchar default null)
begin
    
    declare local temporary table #data(entity long varchar,
                                        restriction long varchar,
                                        primary key(entity));

    -- SP public
    insert into #data with auto name
    select sp.proc_name as entity
      from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                               join sys.sysprocperm perm on perm.proc_id = sp.proc_id
                               join sys.sysuserperm sup on perm.grantee = sup.user_id
    where sup.user_name = 'PUBLIC';
    
    
    insert into #data on existing update with auto name
    select name as entity,
           list(id) as restriction
      from openxml(@roles,'/data/roles/role')
           with(name long varchar '@name', id long varchar '@id')
     group by name;
     
     

    insert into #data with auto name
    select 'dbo.measures' as entity;

    select entity,
           restriction
      from #data;

end
;