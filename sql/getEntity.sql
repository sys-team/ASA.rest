create or replace function ar.getEntity(
    @entity long varchar,
    @code long varchar default isnull(replace(http_header('Authorization'), 'Bearer ', ''), http_variable('Authorization'))
)
returns xml
begin
    declare @result xml;
    declare @entityId integer;
    declare @entityType varchar(128);
    
    select entityId,
           entityType
      into @entityId, @entityType
      from ar.entityDescription(@entity);
    
    
    
    



    return @result;
end
;
