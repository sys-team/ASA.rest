create or replace procedure ar.spResultSet(@entity long varchar)
begin

    select pp.parm_name
      from sys.sysprocedure p join sys.sysuserperm u on p.creator = u.user_id
                              join sys.sysprocparm pp on pp.proc_id = p.proc_id
     where u.user_name =  left(@entity, locate(@entity,'.') -1)
       and p.proc_name = substr(@entity, locate(@entity,'.') +1)
       and parm_type = 0;
       
end
;