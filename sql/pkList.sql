create or replace procedure ar.pkList(
    @entityName long varchar default null,
    @entityId integer default null
)
begin
    if @entityId is null then
        set @entityId = (select entityId
                           from ar.entityIdAndType(@entityName, 'table'));
    end if;
    
    select column_name
      from sys.syscolumn
     where table_id = @entityId
       and pkey = 'Y'
     order by column_id;
     
end
;