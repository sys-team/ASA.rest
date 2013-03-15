create or replace function ar.csv(
    @url long varchar,
    @authType long varchar default 'basic',
    @code long varchar default isnull(nullif(replace(http_header('Authorization'), 'Bearer ', ''),''), http_variable('authorization:'))
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @errorCode long varchar;
    declare @action long varchar;
    declare @roles xml;
    declare @cts datetime;
    
    declare local temporary table #variable(
        name long varchar,
        value long varchar,
        operator varchar(64) default '='
    );
    
    set @cts = now();
    
    if varexists('@xid') = 0 then create variable @xid GUID end if;

    set @xid = newid();

    insert into ar.log with auto name
    select @xid as xid,
           @url as url,
           @code as code;
           
    if @authType <> 'basic' then
        set @roles = util.UOAuthAuthorize(@code);
    end if; 
           
    -- http variables
    insert into #variable with auto name
    select name,
           value
      from util.httpVariables();
      
    update ar.log 
      set variables = (select list(name +'='+value, '&') from #variable where name = 'columns:')
     where xid = @xid;
     
    
    select action
      into @action
      from openstring(value isnull(@url,''))
           with (action long varchar)
           option(delimited by '/') as t;
     
    -- check @roles
    if not exists(select *
                    from openxml(@roles,'/*:response/*:roles/*:role')
                         with(code long varchar '*:code')
                   where code = 'authenticated') and @authType <> 'basic' then
                   
        set @response = xmlelement('error', 'Not authenticated');
    else
        case @action
            when 'post' then
                set @response = ar.csvPost(@url);
        end case;
        

    end if;
    
    set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns",
                                             @xid as "xid",
                                             now() as "ts",
                                             @cts as "cts",
                                             @@servername as "servername",
                                             db_name() as "dbname",
                                             property('machinename') as "host"), @response);

    ----------
    update ar.log
       set response = @response
     where xid = @xid;
     
    return @response;
    
    exception  
        when others then
        
            set @error = errormsg();
            if @error like 'RAISERROR executed: %' then
                set @errorCode =  trim(substring(@error, locate(@error,'RAISERROR executed: ') + length('RAISERROR executed: ')));
            end if;

            rollback;       
            
            set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns",now() as "ts"),
                                                   xmlelement('error', xmlattributes(@errorCode as "code"), @error));
            
            update ar.log
               set response = @response
            where xid = @xid;
            
            return @response;
end
;