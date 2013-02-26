create or replace procedure ar.parsePredicate()
begin

    for lloop as ccur cursor for
    select id as c_id,
           rawPredicate as c_rawPredicate,
           rawPermPredicate as c_rawPermPredicate
      from #entity
     where rawPredicate is not null
        or rawPermPredicate is not null
    do
    
        if c_rawPredicate is not null then
        
            insert into #predicate with auto name
            select c_id as entityId,
                   predicate
              from openstring(value c_rawPredicate)
                   with(predicate long varchar)
                   option(delimited by '~' row delimited by '&') as t
             where predicate not like '%`%';
             
            insert into #joins with auto name
            select c_id as child,
                   c_id - 
                   (select count(*) - 1
                      from openstring(value predicate)
                           with(d long varchar)
                           option(delimited by '~' row delimited by '`') as tt) as parent,
                  left(predicate, locate(predicate, '`') - 1) as childColumn,
                  substr(predicate, locate(predicate, '`', -1) + 1) as parentColumn
              from openstring(value c_rawPredicate)
                   with(predicate long varchar)
                   option(delimited by '~' row delimited by '&') as t
             where predicate like '%`%';
             
        elseif c_rawPermPredicate is not null then

            insert into #predicate with auto name
            select c_id as entityId,
                   predicate
              from openstring(value c_rawPermPredicate)
                   with(predicate long varchar)
                   option(delimited by '~' row delimited by '&') as t
             where predicate <> '*';
         
        end if; 
         
    end for;
    
    update #predicate
       set predicate = replace(predicate, '"', '');    
    
    update #predicate
       set predicate = (select top (1)
                               column_name
                          from ar.pkList(@entityId = e.entityId)) + '=' + p.predicate
      from #predicate p  join #entity e on p.entityId = e.id
     where isnumeric(p.predicate) = 1
       and isnull(p.predicate,'') <> '';
     
    update #predicate
       set predicate = 'xid=' + predicate
     where util.strtoxid(predicate) is not null
       and isnull(predicate,'') <> '';
    ---
    update #predicate
       set predicate = '[' + replace(predicate,'%=','] like ''') + '''',
           predicateColumn = left(predicate, locate(predicate,'%=') - 1)
     where isnull(predicate,'') <> ''
       and locate(predicate, '%=') <> 0;
    
    update #predicate
       set predicateColumn = left(predicate, locate(predicate,'<')- 1)
     where predicate like '%<%';
     
    update #predicate
       set predicateColumn = left(predicate, locate(predicate,'>')- 1)
     where predicate like '%>%';
     
    update #predicate
       set predicateColumn = left(predicate, locate(predicate,'=')- 1)
     where predicateColumn is null;
    ---
    update #predicate
       set predicate = '[' + replace(predicate,'=',']=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate not like '%<%'
       and predicate not like '%>%'
       and predicate not like '%like%';
     
    update #predicate
       set predicate = '[' + replace(predicate,'<=',']<=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%<=%';
       
    update #predicate
       set predicate = '[' + replace(predicate,'>=',']>=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%>=%';
       
    update #predicate
       set predicate = '[' + replace(predicate,'<',']<''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%<%'
       and predicate not like '%<=%';
       
    update #predicate
       set predicate = '[' + replace(predicate,'>',']>''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%>%'
       and predicate not like '%>=%';
      
    update #predicate
       set predicate = csconvert(predicate, 'char_charset', 'utf-8');

end
;