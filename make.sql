create or replace function ar.make(
    @url long varchar
)
returns xml
begin
    declare @response xml;
    declare @entity long varchar;
    declare @id integer;
    declare @xid GUID;
    
    -- url elements
    select entity
      into @entity
      from openstring(value @url)
           with (serv long varchar, entity long varchar, id long varchar)
           option(delimited by '/') as t;
    
    insert into ar.collection with auto name
    select @entity as name;
    
    set @id = @@identity;
    
    set @xid = (select xid
                 from ar.collection
                where id = @id);
                
    set @response = xmlelement('collection', xmlattributes(@entity as "name", @xid as "xid"));
                                               
    return @response;
end
;