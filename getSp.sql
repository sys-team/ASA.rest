create or replace function ar.getSp(
    @entityName long varchar,
    @entityId integer,
    @pageSize integer,
    @pageNumber integer,
    @orderBy long varchar default 'id',
    @whereClause long varchar default null
)
returns xml
begin
    declare @result xml;
    
    
    
    
    return @result;
end
;