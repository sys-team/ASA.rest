create or replace function ar.gutGet(
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id')
)
returns xml
begin
    declare @result xml;
    declare @entityId integer;
    declare @restriction long varchar;
    
    case @objectType
        when 'table' then
            delete from #variable where name = 'code';
        
            set @entityId = (select table_id
                               from sys.systable t join sys.sysuserperm u on t.creator = u.user_id
                              where t.table_name = @objectName
                                and u.user_name = @objectOwner);
                                
            set @restriction = (select restriction
                                  from #roles
                                 where entity = @entity);
        
            set @result = ar.getTable(@entity, @entityId, @pageSize, @pageNumber, @orderBy, null, @restriction);
        
        when 'sp' then
        
    end case;
     
    
    return @result;
end
;