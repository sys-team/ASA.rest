create or replace function ar.parseEntity(
    @entityName long varchar
)
returns long varchar
begin
    declare @result long varchar;
    
    set @result = '[' + left(@entityName, locate(@entityName,'.') -1) + '].[' + substr(@entityName, locate(@entityName,'.') +1) + ']';
    
    return @result;
end
;