create or replace function ar.rest(
    @url long varchar,
    @pageSize integer default if isnumeric(http_variable('page-size:')) = 1 then http_variable('page-size:') else 10 endif,
    @pageNumber integer default if isnumeric(http_variable('page-number:')) = 1 then http_variable('page-number:') else 1 endif,
    @orderBy long varchar default isnull(http_variable('order-by:'),'id')
)
returns xml
begin
    declare @response xml;
    declare @varName long varchar;
    declare @varValue long varchar;
    declare @error long varchar;
    declare @entity long varchar;
    declare @entityId integer;
    declare @isSp integer;
    declare @code long varchar;
    declare @id long varchar;
    declare @recordId bigint;
    declare @recordXid uniqueidentifier;
    declare @sql long varchar;
    declare @rawData xml;
    
    declare local temporary table #filter(attribute long varchar,
                                          value long varchar);
    
    set @code = replace(http_header('Authorization'), 'Bearer ', '');
    -- Authorization
    
    /////////////
    
    -- url elements
    select entity,
           id
      into @entity, @id
      from openstring(value @url)
           with (entity long varchar, id long varchar)
           option(delimited by '/') as t;
           
    -- parms
    if @id is not null then
        if isnumeric(@id) = 1 then
            set @recordId = cast(@id as bigint);
        else
            set @recordXid = util.strtoxid(@id);
        end if;        
    end if;
    --  http variables
    set @varName = next_http_variable(null);
    
    while @varName is not null loop
        set @varValue = http_variable(@varName);
        
        if @varName not like '%:' and @varName not in ('url') then
            insert into #filter with auto name
            select @varName as attribute,
                   @varValue as value;
        end if;

        set @varName = next_http_variable(@varName);
        
    end loop;
    

    set @entityId = (select sp.proc_id
                       from sys.sysprocedure sp join sys.sysuserperm su on sp.creator = su.user_id
                      where sp.proc_name =  substr(@entity, locate(@entity,'.') +1)
                        and su.user_name =  left(@entity, locate(@entity,'.') -1));
                        
    if @entityId is not null then      
        set @isSp = 1;
    else
        set @isSp = 0;
        
        set @entityId = (select st.table_id
                       from sys.systable st join sys.sysuserperm su on st.creator = su.user_id
                      where st.table_name =  substr(@entity, locate(@entity,'.') +1)
                        and su.user_name =  left(@entity, locate(@entity,'.') -1));
    end if;
    
    if @entityId is null then
        raiserror 55555 'Entity %1 not found', @entity;
    end if;
    
    if @isSp = 0 then
                       
        set @sql = 'select top ' + cast(@pageSize as varchar(64)) + ' ' +
                   ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
                   ' * '+
                   'from ' + @entity +
                   if @recordId is not null then ' where id = ' + cast(@recordId as varchar(64)) else '' endif +
                   if @recordXid is not null then ' where xid = ''' + uuidtostr(@recordXid) + '''' else '' endif +
                   if @recordXid is null and @recordId is null and (select count(*) from #filter) <> 0 then ' where ' else '' endif +
                   (select list(attribute +'='''+value+'''', ' and ') from #filter) + 
                   ' order by '+ @orderBy + ' for xml raw, elements';
                   
        message 'ar.rest @sql for @rawData = ', @sql;
        set @sql = 'set @rawData = (' + @sql +')';
        
        execute immediate @sql;
    
        set  @sql = 'select xmlagg(xmlelement(''row'', xmlattributes(''' + @entity + ''' as "name"' +
                            ', id as "id"' +
                            ', xid as "xid"' +' ),' +
                            '(select xmlagg(xmlelement(''value'', ' +
                            'xmlattributes(name as "name") , value)) ' +
                            'from openxml(r ,''/row/*'') '+
                            'with ( name long varchar ''@mp:localname'', value long varchar ''.'')' +
                            ' where name not in (''id'', ''xid'') '+
                            ')' + 
                            ')) from ' +
                    '(select r, id, xid '+
                    ' from openxml(xmlelement(''root'',@rawData), ''/root/row'') ' +
                    ' with(r xml ''@mp:xmltext'', id long varchar ''id'', xid long varchar ''xid'')) as t';

    elseif @isSp = 1 then
    
        set @sql = 'select ''noy implemented yet''';
    
    end if;
    
    --message 'ar.rest @sql = ', @sql;
    set @sql = 'set @response = (' + @sql +')';
    
    execute immediate @sql;
    
    set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns"), @response);

    return @response;
    
    exception  
        when others then
        
            set @error = errormsg();
            --call op.errorHandler('arrest',SQLSTATE, @error); 
            --call dbo.sa_set_http_header('@HttpStatus', '404');
            
            set @response = xmlelement('response', xmlattributes('https://github.com/sys-team/ASA.rest' as "xmlns"), xmlelement('error', @error));

            return @response;
end
;