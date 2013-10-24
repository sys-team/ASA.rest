create or replace function ar.chestToRawData(
    @entity STRING,
    @rawData xml
)
returns xml
begin
    declare @result xml;
    
    declare local temporary table #parsed(
        xid STRING,
        name STRING,
        data STRING,
        xmlData xml,
        primary key(xid, name)
    );

    if exists(select *
                from openxml(xmlelement('root', @rawData), '/root/row')
                     with(xid STRING 'xid', ts STRING 'ts') as t 
                     join ch.entity e on e.xid = t.xid and e.ts > t.ts)
    and @entity <> 'ch.entity' then
                     
        insert into #parsed with auto name
        select t.xid,
               td.name,
               td.data,
               td.xmlData
         from openxml(xmlelement('root', @rawData), '/root/row')
              with(xid STRING 'xid', ts STRING 'ts', xmlData xml '@mp:xmltext') as t 
              outer apply (select *
                             from openxml(t.xmlData, '/row/*')
                                  with (
                                        name STRING '@mp:localname',
                                        data STRING '.',
                                        xmlData xml '*/@mp:xmltext'
                                        )) as td;
                                   
        insert into #parsed on existing update with auto name
        select t.xid,
               ed.name,
               ed.data,
               ed.xmlData
          from openxml(xmlelement('root', @rawData), '/root/row')
               with(xid STRING 'xid', ts STRING 'ts', xmlData xml '@mp:xmltext') as t 
               join ch.entity e on e.xid = t.xid 
               outer apply (select *
                              from openxml(e.xmlData,'/d/*')
                                   with (
                                        name STRING '@name',
                                        data STRING '.',
                                        xmlData xml '*/@mp:xmltext'
                                        )
                             where data is not null) as ed
         where e.ts > cast(t.ts as datetime);
                        
        set @result = (
            select xmlagg(r)
            from (select xmlelement('row',xmlagg(xmlelement(name, data))) as r
                    from #parsed
                   group by xid) as t
            )
                                 
    else                 
        set @result = @rawData;
    end if;

    return @result;
end
;