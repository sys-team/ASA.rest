create or replace function ar.getRecordByXid(@entityName long varchar, @xid uniqueidentifier)
returns xml
begin
    declare @result xml;
    declare @sql long varchar;
    
    set @sql = 'set @result = '
             + '(select * '
             + 'from [' + left(@entityName, locate(@entityName,'.') -1) + '].[' + substr(@entityName, locate(@entityName,'.') +1) + '] '
             + 'where xid = ''' + uuidtostr(@xid) + ''' '
             + 'for xml raw, elements)';
             
    execute immediate @sql;

    return @result;
end
;