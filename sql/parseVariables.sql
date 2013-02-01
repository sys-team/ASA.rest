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

end
;