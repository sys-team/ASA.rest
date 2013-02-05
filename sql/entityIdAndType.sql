create or replace procedure ar.entityIdAndType(@entityName long varchar)
begin
    declare @entityId integer;
    declare @entityType long varchar;
    
    set @entityId = (select id
                       from ar.collection
                      where name = @entityName);
                      
    if @entityId is not null then
        set @entityType = 'collection';
    else
        set @entityId = (select sp.proc_id
                           from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                          where sp.proc_name =  substr(@entityName, locate(@entityName,'.') +1)
                            and su.user_name =  left(@entityName, locate(@entityName,'.') -1));
                            
        if @entityId is not null then      
            set @entityType = 'sp';
        else
            set @entityType = 'table';
            
            set @entityId = (select st.table_id
                              from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                             where st.table_name =  substr(@entityName, locate(@entityName,'.') +1)
                               and su.user_name =  left(@entityName, locate(@entityName,'.') -1));
        end if;
    end if;
    
    
    select @entityId as entityId,
           @entityType as entityType;
end
;