create or replace  function ar.parseColumns(
    @entityId integer,
    @columns long varchar,
    @alias long varchar default null
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
    select column_name as c_column_name
      from sys.syscolumn left outer join (select name
                                            from openstring(value @columns)
                                                 with(name long varchar)
                                                 option(delimited by '@' row delimited by ',') as c
                                           where name not like '%(%)'
                                           union distinct
                                           select 'xid') as t on column_name = t.name
     where table_id = @entityId
       and (@columns ='*'
        or name is not null)
       
    do
        if length(@result) <> 0 then
            set @result = @result +',';
        end if;
        
        if ar.columnDatatype(@entityId, c_column_name) = 'xml' then
            set @result = @result + '(select d from openxml(' +
                                    c_column_name + ', ''/*'') with(d xml ''@mp:xmltext''))' + ' as '+ c_column_name;
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