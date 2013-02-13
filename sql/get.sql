create or replace function ar.get(
    @url long varchar
)
returns xml
begin
    declare @response xml;
    
    set @response = ar.getQuery(@url);
    
    return @response;

end
;