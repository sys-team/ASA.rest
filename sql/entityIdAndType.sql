create or replace procedure ar.entityIdAndType(
    @entityName STRING,
    @desiredType STRING default null
)
begin
    declare @entityId integer;
    declare @entityType STRING;

    if @desiredType is null then

        set @desiredType = (
            select type
            from ch.dataSource
            where entity = @entityName
        );

    end if;

    if @desiredType is null then
        set @desiredType = util.getUserOption('ch.preferedEntityType');
    end if;

    set @entityId = (
        select sp.proc_id
        from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
        where sp.proc_name =  substr(@entityName, locate(@entityName,'.') +1)
            and su.user_name =  left(@entityName, locate(@entityName,'.') -1)
            and (
                @desiredType = 'sp'
                or @desiredType is null
            )
            and not exists (
                select *
                from sys.sysprocparm
                where proc_id = sp.proc_id
                and parm_type = 4
            )
    );  

    if @entityId is not null then
        set @entityType = 'sp';
    else

        set @entityId = (
            select st.table_id
            from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
            where st.table_name =  substr(@entityName, locate(@entityName,'.') +1)
                and su.user_name =  left(@entityName, locate(@entityName,'.') -1)
                and (
                    @desiredType = 'table'
                    or @desiredType is null
                )
        );

        if @entityId is not null then
            set @entityType = 'table';
        else

            set @entityId = (
                select id
                from ar.collection
                where name = @entityName
                    and (
                        @desiredType = 'collection'
                        or @desiredType is null
                    )
            );

            if @entityId is not null then
                set @entityType = 'collection';
            end if;

        end if;

    end if;

    select @entityId as entityId,
           @entityType as entityType;

end
;
