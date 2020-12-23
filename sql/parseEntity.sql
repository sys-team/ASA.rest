create or replace function ar.parseEntity(
    @entityName STRING
) returns STRING deterministic
begin
    declare @result STRING;

    set @result = string(
        '[',
        replace(@entityName, '.', '].['),
        ']'
    );

    return @result;

end
;
