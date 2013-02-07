create or replace  function ar.parseColumns(@entityId integer, @columns long varchar)
returns long varchar
begin
    declare @result long varchar;
    
    if @columns <> '*' then
        set @columns = replace(@columns, '[', '''');
        set @columns = replace(@columns, ']', '''');
    end if;
    
    for lloop as ccur cursor for
    select column_name as c_column_name
      from sys.syscolumn left outer join (select name
                                            from openstring(value @columns)
                                                 with(name long varchar)
                                                 option(delimited by '@' row delimited by ',') as c) as t on column_name = t.name
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
            set @result = @result + c_column_name;
        end if;
    end for;
    
    return @result;
end
;