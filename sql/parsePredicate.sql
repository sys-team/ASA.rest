create or replace procedure ar.parsePredicate()
begin

    for lloop as ccur cursor for
    select id as c_id,
           rawPredicate as c_rawPredicate
      from #entity
     where rawPredicate is not null
    do
    
        insert into #predicate with auto name
        select c_id as entityId,
               predicate
          from openstring(value c_rawPredicate)
               with(predicate long varchar)
               option(delimited by '~' row delimited by '&') as t;
    
    end for;

    update #predicate
       set predicate = 'id=' + predicate
     where isnumeric(predicate) = 1
       and isnull(predicate,'') <> '';
     
    update #predicate
       set predicate = 'xid=' + predicate
     where util.strtoxid(predicate) is not null
       and isnull(predicate,'') <> '';
    ---
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
       and predicate not like '%>%';
     
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