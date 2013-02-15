create or replace function ar.processXML(
    @xml xml
)
returns xml
begin
    declare @result xml;
    
    if @xml like  '<?xml%' then
        set @result = (select d from openxml(@xml, '/*') with(d xml '@mp:xmltext'));
    else
        set @result = @xml;
    end if;
 
    
    return @result;
end
;
