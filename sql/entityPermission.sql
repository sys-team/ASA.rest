create or replace function ar.entityPermission (
    @owner long varchar,
    @entity long varchar,
    @permissionType long varchar default 'read',
    @accessToken long varchar default isnull(nullif(replace(http_header('Authorization'), 'Bearer ', ''),''),
                                             http_variable('authorization:')),
    @server long varchar default @@servername,
    @database long varchar default db_name()
)
returns integer
begin
    declare @result integer;
    
    set @result = 0;
    
    -- Servername.database dba role
    if exists(select *
                from uac.token t join uac.tokenRole r on t.id = r.token
               where t.token = @accessToken
                 and r.code = @server + '.' + @database
                 and r.data = 'dba') then
        set @result = 1;
    -- entity name role    
    elseif exists(select *
                    from uac.token t join uac.tokenRole r on t.id = r.token
                   where t.token = @accessToken
                     and r.code = @owner + '.' + @entity) then
        set @result = 1;
    -- owner role
    elseif exists(select *
                    from uac.token t join uac.tokenRole r on t.id = r.token
                   where t.token = @accessToken
                     and r.code = @owner) then
        set @result = 1;
    -- arest.read.servername.database role
    elseif exists(select *
                from uac.token t join uac.tokenRole r on t.id = r.token
               where t.token = @accessToken
                 and r.code = 'arest.read.' + @server + '.' + @database
                 and locate('|' + r.data + '|', '|' + @owner + '.' + @entity +'|') <> 0) then
        set @result = 1;
    end if;
    
    return @result;

end
;