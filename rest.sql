create or replace function ar.rest(@url long varchar)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @entity long varchar;
    declare @entityId integer;
    declare @isSp integer;
    declare @isId integer;
    declare @isXid integer;
    declare @code long varchar;
    declare @id long varchar;
    declare @pageSize integer;
    declare @pageNumber integer;
    declare @orderBy long varchar;
    declare @recordId bigint;
    declare @recordXid uniqueidentifier;
    declare @sql long varchar;
    
    select entity,
           id
      into @entity, @id
      from openstring(value @url)
           with (entity long varchar, id long varchar)
           option(delimited by '/') as t;
           
    set @pageSize = if isnumeric(http_variable('page-size')) = 1 then http_variable('page-size') else 10 endif;
    set @pageNumber = if isnumeric(http_variable('page-number')) = 1 then http_variable('page-number') else 1 endif;
    set @orderBy = isnull(http_variable('order-by'),'id');
    
    set @code = replace(http_header('Authorization'), 'Bearer ', '');

    -- Authorization
    
    
    -- parms
    if @id is not null then
        if isnumeric(@id) = 1 then
            set @recordId = cast(@id as bigint);
        else
            set @recordXid = util.strtoxid(@id);
        end if;        
    end if;

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
    
        set @isId = (select count(*)
                       from sys.syscolumn
                      where table_id = @entityId
                        and column_name in ('id'));
                        
        set @isXid = (select count(*)
                       from sys.syscolumn
                      where table_id = @entityId
                        and column_name in ('xid'));                   
    
        set  @sql = 'select xmlagg(xmlelement(''row'', xmlattributes(''' + @entity + ''' as "name"' +
                            if @isId <> 0 then ', id as "id"' else '' endif +
                            if @isXid <> 0 then ', xid as "xid"' else '' endif +' ),' +
                            '(select xmlagg(xmlelement(''value'', ' +
                            'xmlattributes(name as "name") , value)) ' +
                            'from openxml(xmlelement(''root'', r) ,''/root/*'') '+
                            'with ( name long varchar ''@mp:localname'', value long varchar ''.'')' + 
                            ')' + 
                            ')) from ' +
                    (select '(select top ' + cast(@pageSize as varchar(64)) + ' ' +
                            ' start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
                            ' xmlforest(' + list(column_name) + ') as r'
                            + if @isId <> 0 then ', id' else '' endif
                            + if @isXid <> 0 then ', xid' else '' endif
                       from sys.syscolumn
                      where table_id = @entityId
                        and column_name not in ('id', 'xid')) +
                    ' from ' + @entity +
                    if @recordId is not null and @isId <> 0 then ' where id = ' + cast(@recordId as varchar(64)) else '' endif +
                    if @recordXid is not null and @isXid <> 0 then ' where xid = ''' + uuidtostr(@recordXid) + '''' else '' endif +
                    ' order by '+ @orderBy +') as t';

    elseif @isSp = 1 then
    
         set @isId = (select count(*)
                       from sys.sysprocparm
                      where proc_id = @entityId
                        and parm_mode_out ='Y'
                        and parm_name in ('id'));
                        
        set @isXid = (select count(*)
                       from sys.sysprocparm
                      where proc_id = @entityId
                        and parm_mode_out ='Y'
                        and parm_name in ('xid'));    
    
        set  @sql = 'select xmlagg(d) from (' +
                    'select top ' + cast(@pageSize as varchar(64)) + ' ' +
                    'start at ' + cast((@pageNumber -1) * @pageSize + 1 as varchar(64)) + ' '+
                    'xmlelement(''row'', xmlattributes(''' + @entity + ''' as "name"'
                    + if @isId <> 0 then ', id as "id"' else '' endif +
                    + if @isXid <> 0 then ', xid as "xid"' else '' endif +' ),' +
                    (select 'xmlconcat('+
                            list(' if ' + parm_name + ' is not null then  xmlelement(''value'', xmlattributes('''+parm_name+''' as "name"),'+parm_name +') else null endif') +')'
                       from sys.sysprocparm
                      where proc_id = @entityId
                        and parm_mode_out ='Y'
                        and parm_name not in ('id', 'xid')) +
                    ') as d from ' + @entity + '()' +
                    if @recordId is not null and @isId <> 0 then ' where id = ' + cast(@recordId as varchar(64)) else '' endif +
                    if @recordXid is not null and @isXid <>0 then ' where xid = ''' + uuidtostr(@recordXid) + '''' else '' endif +
                    ' order by '+ @orderBy +
                    ') as t';
    
    end if;
    
    message 'ar.rest @sql = ', @sql;
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