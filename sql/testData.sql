create or replace function ar.testData(
    @url STRING,
    @domain STRING default http_variable('domain:')
)
returns xml
begin
    declare @result xml;

    if @domain is null then
        set @domain = regexp_substr(@url,'(?<=/)[^/]+');
    end if;
    
    set @result = isnull((select data
                            from ar.testData
                           where domain = @domain),
                         xmlelement('error', 'Domain not found'));
    
    -- cut response element
    if (select count(*)
          from openxml(@result, '/*')
               with(response STRING '*:response')) <> 0 then
               
        set @result = (select xmlagg(data)
                         from openxml(@result, '/*/*')
                              with(data xml '@mp:xmltext'));
                              
    end if;
                         
    return @result;
end
;