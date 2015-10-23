create or replace function ar.objectWithXidName (
    @xid guid,
    @name string,
    @etc xml default null
) returns xml begin

    return xmlelement('Object',
        xmlelement ('guid',xmlattributes('id' as name),@xid),
        xmlelement ('s',xmlattributes('name' as name),@name),
        @etc
    );

end;
