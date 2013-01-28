create or replace function ar.queryRoles(@code long varchar)
returns xml
begin
    declare @result xml;
    
    set @result = util.UOAuthAuthorize(@code);
    
    return @result;
end;
