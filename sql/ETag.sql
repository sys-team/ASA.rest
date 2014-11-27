create or replace function ar.ETagFromTsAndId (
    @ts timestamp,
    @id BIGINT,
    @version int default '1'
) returns STRING DETERMINISTIC 
begin

    declare @result STRING;
    
    set @result = string (
        @version,
        '-',
        util.offsetFromTs(@ts),
        '-',
        @id
    );

    return @result;

end;


create or replace function ar.versionFromETag (
    @etag STRING
) returns string DETERMINISTIC 
begin

    declare @result timestamp;
    
    set @result = util.tsFromOffset(regexp_substr(@etag,'^[^-]*'));

    return @result;
    
    exception
        when others then return null;

end;


create or replace function ar.tsFromETag (
    @etag STRING
) returns timestamp DETERMINISTIC 
begin

    declare @result timestamp;

    set @result = util.tsFromOffset(
        isnull(
            nullif(
                regexp_substr(@etag,'(?<=^.*[-])[^-]*'),''
            )
        ,'19000101000000')
    );

    return @result;
    
    exception
        when others then return null;

end;


create or replace function ar.idFromETag (
    @etag STRING
) returns BIGINT DETERMINISTIC 
begin

    declare @result BIGINT;
    
    set @result = regexp_substr(@etag,'[^-]*$');

    return cast (@result as BIGINT);
    
    exception
        when others then return null;

end;
