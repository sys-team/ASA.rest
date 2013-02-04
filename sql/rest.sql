create or replace function ar.rest(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @code long varchar default isnull(http_header('Authorization'),http_variable('authorization:') )
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @errorCode long varchar;
    declare @entity long varchar;
    declare @parentEntity long varchar;
    declare @action long varchar;
    declare @authorized integer;
    declare @cts datetime;
    declare @xid uniqueidentifier;
    declare @varName long varchar;
    declare @rowcount integer;
    
    declare local temporary table #variable(name long varchar,
                                            value long varchar,
                                            operator varchar(64) default '=');
    
    set @cts = now();
    set @xid = newid();

    
     insert into ar.log with auto name
     select @xid as xid,
            @url as url,
            @code as code;  
    
    select action,
           entity,
           parentEntity
      into @action, @entity, @parentEntity
      from openstring(value @url)
           with (action long varchar, entity long varchar, id long varchar, parentEntity long varchar)
           option(delimited by '/') as t;
           
    set @authorized = ar.authorize(@code, @entity);
    
    -- http variables
    insert into #variable with auto name
    select name,
           value
      from util.httpVariables();
      
    update ar.log 
      set variables = (select list(name +'='+value, '&') from #variable)
     where xid = @xid;
      
    -- entity id & entity type       
    if varexists('@entityId') = 0 then create variable @entityId integer end if;
    if varexists('@entityType') = 0 then create variable @entityType varchar(128) end if;
    
    set @entityId = (select id
                       from ar.collection
                      where name = @entity);
                      
    if @entityId is not null then
        set @entityType = 'collection';
    else
        set @entityId = (select sp.proc_id
                           from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                          where sp.proc_name =  substr(@entity, locate(@entity,'.') +1)
                            and su.user_name =  left(@entity, locate(@entity,'.') -1));
                            
        if @entityId is not null then      
            set @entityType = 'sp';
        else
            set @entityType = 'table';
            
            set @entityId = (select st.table_id
                              from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                             where st.table_name =  substr(@entity, locate(@entity,'.') +1)
                               and su.user_name =  left(@entity, locate(@entity,'.') -1));
        end if;
    end if;
           
    -- Authorization
    if @authorized = 0 then
        set @response = xmlelement('response', xmlelement('error', xmlattributes('NotAuthorized' as "code"), 'Not authorized'));
    else
        case @action
            when 'get' then
                set @response = ar.get(@url);
            when 'put' then
                set @response = ar.put(@url);
            when 'make' then
                set @response = ar.make(@url);
            when 'addElement' then
                set @response = ar.addElement(@url);
            when 'link' then
                set @response = ar.link(@url);
        end case;
    end if;
    
    set @rowcount = (select count(*)
                       from openxml(xmlelement('root',@response), '/root/d')
                            with(name long varchar '@name'));
    
    set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns",
                                                         @xid as "xid",
                                                         now() as "ts",
                                                         @cts as "cts",
                                                         @pageSize as "page-size",
                                                         @pageNumber as "page-number",
                                                         @rowcount as "page-row-count",
                                                         @@servername as "servername",
                                                         db_name() as "dbname",
                                                         property('machinename') as "host"), @response);
                                                         
    update ar.log
       set response = left(@response,65536)
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