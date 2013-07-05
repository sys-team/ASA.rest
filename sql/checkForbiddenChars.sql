create or replace function ar.checkForbiddenChars(
    @data long varchar
)
returns integer
begin
    
    if @data regexp '.*(;|\[|\]|'').*' then
        return 1;
    end if;

    return 0;
end
;