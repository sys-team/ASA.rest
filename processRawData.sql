create or replace function ar.processRawData(
    @entity long varchar,
    @entityId integer,
    @entityType long varchar,
    @rawData xml
)
returns xml
begin
    declare @result xml;
    declare @sql long varchar;
    
    set  @sql = 'select xmlagg(xmlelement(''row'', xmlattributes(''' + @entity + ''' as "name"' +
                ', xid as "xid"' +' ),' +
                '(select xmlagg(xmlelement(' +
                'ar.columnDatatype(' + cast(@entityId as varchar(24)) + ',name,''' + @entityType + '''),' +
                'xmlattributes(name as "name", f.parent as "parent", lat.xid as "parent-xid") , value)) ' +
                'from openxml(r ,''/row/*'') '+
                'with ( name long varchar ''@mp:localname'', value long varchar ''.'') as r ' +
                ' left outer join (select foreignColumn, list(entityName order by entityName) as parent, '+
                ' list(primaryColumn order by entityName) as parentColumns ' +
                ' from #fk group by foreignColumn) as f '+
                ' on r.name = f.foreignColumn ' +
                ' outer apply (select xid from ar.xidById(r.[name],r.[value]))' +
                ' as lat' +
                ' where r.name not in (''xid'') '+
                ')' + 
                ')) from ' +
        '(select r, id, xid '+
        ' from openxml(xmlelement(''root'',@rawData), ''/root/row'') ' +
        ' with(r xml ''@mp:xmltext'', id long varchar ''id'', xid long varchar ''xid'')) as t';
    
    --message 'ar.rest @sql = ', @sql;
    set @sql = 'set @result = (' + @sql +')';
    
    execute immediate @sql;
        
    return @result;
    
end
;