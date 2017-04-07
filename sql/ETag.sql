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
        util.offsetFromTs(@ts, @version),
        '-',
        @id
    );

    return @result;

end;


create or replace function ar.versionFromETag (
    @ETag STRING
) returns STRING DETERMINISTIC
begin

    declare @result STRING;

    set @result =  case @ETag
        when '*' then '1'
        when '**' then '2'
        else regexp_substr(@etag,'^[^-]*')
    end;

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
        ,'19000101000000'),
        ar.versionFromETag(@etag)
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
