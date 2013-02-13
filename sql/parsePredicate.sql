create or replace procedure ar.parsePredicate()
begin

    update #entity
       set predicate = 'id=' + predicate
     where isnumeric(predicate) = 1
       and isnull(predicate,'') <> '';
     
    update #entity
       set predicate = 'xid=' + predicate
     where util.strtoxid(predicate) is not null
       and isnull(predicate,'') <> '';
    ---
    update #entity
       set predicateColumn = left(predicate, locate(predicate,'<')- 1)
     where predicateColumn like '%<%';
     
    update #entity
       set predicateColumn = left(predicate, locate(predicate,'>')- 1)
     where predicateColumn like '%>%';
     
    update #entity
       set predicateColumn = left(predicate, locate(predicate,'=')- 1)
     where predicateColumn is null;
    ---
    update #entity
       set predicate = '[' + replace(predicate,'=',']=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate not like '%<%'
       and predicate not like '%>%';
     
    update #entity
       set predicate = '[' + replace(predicate,'<=',']<=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%<=%';
       
    update #entity
       set predicate = '[' + replace(predicate,'>=',']>=''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%>=%';
       
    update #entity
       set predicate = '[' + replace(predicate,'<',']<''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%<%'
       and predicate not like '%<=%';
       
    update #entity
       set predicate = '[' + replace(predicate,'>',']>''') + ''''
     where isnull(predicate,'') <> ''
       and predicate like '%>%'
       and predicate not like '%>=%';
      
    update #entity
       set predicate = csconvert(predicate, 'char_charset', 'utf-8');

end
;