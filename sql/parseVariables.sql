create or replace procedure ar.parseVariables()
begin

    -- >=
    update #variable
       set name =  left(name, locate(name,'>') -1),
           operator = '>='
     where name like '%>'
       and isnull(value,'') <> '';
       
    -- <=
    update #variable
       set name =  left(name, locate(name,'<') -1),
           operator = '<='
     where name like '%<'
       and isnull(value,'') <> '';
       
    -- <
     update #variable
       set name = left(name, locate(name,'<') -1),
           value = substr(name, locate(name,'<') +1),
           operator = '<'
     where name like '%<%'
       and isnull(value,'') = '';   
    
    -- >
    update #variable
       set name = left(name, locate(name,'>') -1),
           value = substr(name, locate(name,'>') +1),
           operator = '>'
     where name like '%>%'
       and isnull(value,'') = '';
       
    -- in
    update #variable
       set value = '(''' + replace(value, ',' , ''',''')  + ''')',
           operator = 'in'
     where value like '%,%'
       and operator = '=';
       
    -- sql injection
    update #variable
       set value = ''''+value+''''
     where operator not in ('in');
       
    -- utf-8
    update #variable
       set value = csconvert(value, 'char_charset', 'utf-8');

end
;