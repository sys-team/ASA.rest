create or replace procedure ar.entityDescription(@entity long varchar)
begin
    declare @entityId integer;
    declare @entityType varchar(128);
    declare @name long varchar;
    declare @owner long varchar;
    
    set @name = substr(@entity, locate(@entity,'.') +1);
    set @owner = left(@entity, locate(@entity,'.') -1);
    
    set @entityId = (select id
                       from ar.collection
                      where name = @entity);
                      
    if @entityId is not null then
        set @entityType = 'collection';
    else
        set @entityId = (select sp.proc_id
                           from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                          where sp.proc_name =  @name
                            and su.user_name =  @owner);
                            
        if @entityId is not null then      
            set @entityType = 'sp';
        else
            set @entityType = 'table';
            
            set @entityId = (select st.table_id
                              from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                             where st.table_name =  @name
                               and su.user_name =  @owner);
        end if;
    end if;
    
    select @entityId as entityId,
           @entityType as entityType,
           @name as name,
           @owner as owner
     where @entityId is not null;

end
;