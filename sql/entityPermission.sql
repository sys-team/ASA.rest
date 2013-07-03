create or replace function ar.entityPermission (
    @owner long varchar,
    @entity long varchar,
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
   -- elseif exists()
    
 /*   

(select code,
                                           '|' + list(data, '|') + '|' as data
                                      from openxml(@roles,'/*:response/*:roles/*:role')
                                            with(code long varchar '*:code', data long varchar '*:data')
                                     group by code) as roles on (roles.code = #entity.name
                                                               or #entity.name regexp '^' + roles.code + '\..+'
                                                               or (locate(roles.data, '|' + #entity.name +'|') <> 0
                                                              and roles.code = 'arest.read.' + @@servername + '.' + db_name()));
                                                              
                                                              */

    return @result;

end
;