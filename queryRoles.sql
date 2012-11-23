create or replace function ar.queryRoles(@code long varchar)
returns xml
begin
    declare @result xml;
    
    set @result = xmlelement('response', ea.roles(@code));
    
    return @result;
end;
