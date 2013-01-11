create or replace function ar.gut(
    @url long varchar,
    @code long varchar default isnull(nullif(replace(http_header('Authorization'), 'Bearer ', ''),''), http_variable('code')),
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id')
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @errorCode long varchar;
    declare @xid GUID;
    declare @cts datetime;

    declare local temporary table #variable(name long varchar,
                                            value long varchar);
                                            
    declare local temporary table #roles(entity long varchar,
                                         restriction long varchar,
                                         primary key(entity));
                                         
    create variable @action long varchar;
    create variable @entity long varchar;
    create variable @urlId long varchar;
    create variable @objectName long varchar;
    create variable @objectOwner long varchar;
    create variable @objectType long varchar;
    
    set @cts = now();
    set @xid = newid();
 
    
    insert into ar.log with auto name
    select @xid as xid,
           @url as url,
           @code as code;
    
    -- roles       
    insert into #roles with auto name
    select entity,
           restriction
      from ar.permissionByCode(@code);
      
    --set @response = (select xmlelement('roles', xmlagg(xmlforest(entity, restriction))) from #roles);
      
    -- http variables
    insert into #variable with auto name
    select name,
           value
      from util.httpVariables();
      
    update ar.log 
      set variables = (select list(name +'='+value, '&') from #variable)
     where xid = @xid;
     
    -- url
    select action,
           entity,
           urlId
      into @action, @entity, @urlId
      from openstring(value @url)
           with (action long varchar, entity long varchar, urlId long varchar)
           option(delimited by '/') as t;
           
    -- clear roles
    delete from #roles
    where entity <> @entity
      and locate(entity, @entity + '_') <> 1;
       
    -- ?
    set @objectName = substr(@entity, locate(@entity,'.') +1);
    set @objectOwner = left(@entity, locate(@entity,'.') -1);
    set @objectType = 'table';
    
    --message 'ar.gut @code = ', @code, ' @entity = ' , @entity, ' @objectName = ',  @objectName , ' @objectOwner = ', @objectOwner;
    
    select objectOwner,
           objectName,
           objectType
      into @objectOwner, @objectName, @objectType
      from ar.gutFindObject(@objectOwner, @objectName, @objectType);
      
    --message 'ar.gut  @objectName = ',  @objectName , ' @objectOwner = ', @objectOwner;
    -- urlId
    if isnumeric(@urlId) = 1 then
        insert into #variable with auto name
        select 'id' as name,
               @urlId as value;
    elseif util.strtoxid(@urlId) is not null then
        insert into #variable with auto name
        select 'xid' as name,
               @urlId as value;   
    end if;
    
    -- ? action choose
    case @action
        when 'get' then
            set @response = ar.gutGet();
        when 'put' then
            set @response = ar.gutPut();
        when 'findObject' then
            set @response = @response +
                            if @objectName is not null then
                                xmlelement('object-found', xmlattributes(@objectOwner + '.' + @objectName as "name", @objectType as "type"))
                            else
                                xmlelement('object-not-found')
                            endif;
    end case;

    set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns",
                                                         @xid as "xid",
                                                         now() as "ts",
                                                         @cts as "cts",
                                                         @@servername as "servername",
                                                         db_name() as "dbname",
                                                         property('machinename') as "host"), @response);
    ---
    
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