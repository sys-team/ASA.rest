create or replace function ar.addElement(
    @url long varchar
)
returns xml
begin
    declare @result xml;
    declare @entity long varchar;
    declare @tableName long varchar;
    declare @child long varchar;
    declare @id integer;
    declare @xid GUID;
        
    -- url elements
    select entity,
           tableName,
           child
      into @entity, @tableName, @child
      from openstring(value @url)
           with (serv long varchar, entity long varchar, tableName long varchar, child long varchar)
           option(delimited by '/') as t;
           
    if util.strtoxid(@child) is not null then
        
        select id,
               xid
          into @id, @xid
          from ar.collection
         where name = @entity;
         
        if @id is not null then
            insert into ar.element with auto name
            select @child as elementXid,
                   @xid as collectionXid,
                   @id as collection,
                   @tableName as tableName;
                   
            set @result = xmlelement('element', xmlattributes(@xid as "collection", @child as "element"));
            
        else
            set @result = xmlelement('error','Invalid collection');
        end if;
    else
        set @result = xmlelement('error', 'Invalid xid');
    end if;    
    
    return @result;
end
;