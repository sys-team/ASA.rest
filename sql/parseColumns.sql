create or replace  function ar.parseColumns(
    @entityId integer,
    @columns long varchar,
    @alias long varchar default null,
    @entityType long varchar default 'table',
    @longValues integer default 0
)
returns long varchar
begin
    declare @result long varchar;
    declare @i integer;

    if @columns <> '*' then
        set @columns = replace(@columns, '[', '''');
        set @columns = replace(@columns, ']', '''');
    end if;
    
    for lloop as ccur cursor for
    select c.column_name as c_column_name
      from sys.syscolumn c left outer join (select name
                                             from openstring(value @columns)
                                                  with(name long varchar)
                                                  option(delimited by '@' row delimited by ',') as c
                                            where name not like '%(%)'
                                            union distinct
                                            select 'xid') as t on c.column_name = t.name
                           join sys.sysdomain d on c.domain_id = d.domain_id
     where c.table_id = @entityId
       and (@columns ='*'
        or t.name is not null)
       and @entityType = 'table'
       and (d.domain_name not in ('long binary')
        or @columns <> '*'
        or @longValues = 1)
    union
    select p.parm_name
     from sys.sysprocparm p left outer join (select name
                                               from openstring(value @columns)
                                                    with(name long varchar)
                                                    option(delimited by '@' row delimited by ',') as c
                                              where name not like '%(%)'
                                              union distinct
                                              select 'xid') as t on p.parm_name = t.name
     where p.proc_id = @entityId
       and (@columns ='*'
        or name is not null)
       and @entityType = 'sp'
       and parm_type in (1,4)
       
    do
        if length(@result) <> 0 then
            set @result = @result +',';
        end if;
        
        if ar.columnDatatype(@entityId, c_column_name) = 'xml' then
            set @result = @result + '(select xmlagg(d) from openxml(xmlelement(''root'', ar.processXML(' +
                                    if @alias is not null then @alias + '.' else '' endif +
                                    + '[' + c_column_name + '])), ''/*/*'') with(d xml ''@mp:xmltext''))' + ' as '+ c_column_name;
        else
            set @result = @result + if @alias is not null then @alias + '.' else '' endif + '[' + c_column_name + ']';
        end if;
    end for;

    set @i = 1;

    for lloop2 as ccur2 cursor for
    select name as c_name
      from openstring(value @columns)
           with(name long varchar)
           option(delimited by '@' row delimited by ',') as c
     where name like '%(%)'
       and name not like '%;%'
    do
        if length(@result) <> 0 then
            set @result = @result +',';
        end if;
        
        set @result = @result + '[' + left(c_name,locate(c_name,'(') - 1) + '](' +
                      if @alias is not null then @alias + '.' else '' endif + '[' +
                      substring(c_name, locate(c_name,'(') + 1 , length(c_name) - locate(c_name,'(') -1) +'])' +
                      ' as [' + c_name +']';
                      
        set @i = @i + 1;
        
    end for;
    
    return @result;
end
;