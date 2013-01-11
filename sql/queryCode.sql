create or replace function ar.queryCode(@code long varchar)
returns xml
begin
    declare @result xml;

    set @result = (select roles
                     from ea.code
                    where code = @code
                      and now() between cts and ets);
                      
    return @result;
end
;