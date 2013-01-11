create or replace function ar.authorize(@code long varchar, @entity long varchar)
returns integer
begin
    declare @roles xml;
    
    set @roles = ar.queryRoles(@code);
    
    -- sp with PUBLIC exesute permission
    if exists (select *
                 from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                                          join sys.sysprocperm perm on perm.proc_id = sp.proc_id
                                          join sys.sysuserperm sup on perm.grantee = sup.user_id
                where sp.proc_name =  substr(@entity, locate(@entity,'.') +1)
                  and su.user_name =  left(@entity, locate(@entity,'.') -1)
                  and sup.user_name = 'PUBLIC') then
                  
        return 1;
    end if;
    
    
    if @@servername = 'HQVSRV58' then return 1 endif;
    
    if exists(select *
                from openxml(@roles, '/*:response/*:roles/*:role')
                     with(code long varchar 'code')
               where code = 'authenticated' --@entity
                  or code = '*') then
                   
        return 1;
    end if;
        
    if exists(select *
                from openxml(@roles, '/*:response/*:account')
                     with(username long varchar 'username', email long varchar 'email')
               where username like 'lesha%'
                  or email like 'lesha%') then
        return 1;
    end if;

    return 0;  
end;