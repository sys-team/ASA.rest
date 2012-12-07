create or replace function ar.link(
    @url long varchar
)
returns xml
begin
    declare @result xml;
    declare @parent long varchar;
    declare @child long varchar;
    
    -- url elements
    select parent,
           child
      into @parent, @child
      from openstring(value @url)
           with (serv long varchar, parent long varchar, child long varchar)
           option(delimited by '/') as t;
    
    insert into ar.collectionLink with auto name
    select p.xid as parentXid,
           p.id as parent,
           c.xid as childXid,
           c.id as child
      from ar.collection p, ar.collection c
     where p.name = @parent
       and c.name = @child;
       
    set @result = xmlelement('link', xmlattributes(@parent as "parent", @child as "child"));   
    
    return @result;
end
;