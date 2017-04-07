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

    declare local temporary table #columns(
        name STRING,
        dataTypeName STRING,
        primary key(name)
    );

    insert into #columns with auto name
    select distinct name
    from openxml(xmlelement('root', @rawData), '/root/row/*')
        with (name STRING '@mp:localname');

    update #columns
    set dataTypeName = ar.columnDatatype(@entityId, name, @entityType);

    -- message 'ar.processRawData @rawData = ', @rawData;

    set  @sql =
        'select xmlagg(xmlelement(''d'', xmlattributes(''' +
                @entity + ''' as "name"' +
                ', xid as "xid", nanoTs as "nanoTs"' +
            ' ),' +
            '(select xmlagg(' +
            'if r.name = ''___extras'' then ' +
                ' (select xmlagg(extra) from openxml(value,''/*/extra'') with(extra xml ''@mp:xmltext'')) '+
            'else ' +
                'xmlelement(' +
                'cols.dataTypeName,' +
                'xmlattributes(r.name as "name", f.parent as "parent", lat.xid as "parent-xid") , '+
                ' if cols.dataTypeName = ''xml''' +
                ' then ar.processXml(value) else util.xmlEscape(value2) endif ) ' +
            ' endif '+
            ')' +
        'from openxml(r ,''/row/*'') '+
        'with ( name long varchar ''@mp:localname'', value xml ''./@mp:xmltext'', value2 long varchar ''.'') as r ' +
        ' join #columns cols on cols.name = r.name ' +
        ' left outer join (select foreignColumn, list(entityName order by entityName) as parent, '+
        ' list(primaryColumn order by entityName) as parentColumns ' +
        ' from #fk group by foreignColumn) as f '+
        ' on r.name = f.foreignColumn ' +
        ' outer apply (select xid from ar.xidById(r.[name],r.[value2],parentColumns))' +
        ' as lat' +
        ' where r.name not in (''xid'', ''nanoTs'') '+
        ')' +
        ')) from ' +
        '(select * '+
        ' from openxml(xmlelement(''root'',@rawData), ''/root/row'') ' +
        ' with(r xml ''@mp:xmltext'', id STRING ''id'', xid STRING ''xid'', nanoTs STRING ''nanoTs'')) as t'
    ;

    -- message 'ar.processRawData @sql = ', @sql;
    set @sql = 'set @result = (' + @sql +')';

    execute immediate @sql;

    --set @result = @rawData;
    return @result;

end
;
