create or replace procedure dbo.processRestXML(@xml xml)
begin

    declare @currentData xml;
    declare @loopId integer;
    declare @currentId integer;
    declare @currentName long varchar;
    declare @currentParentId integer;
    declare @currentParentName long varchar;
    declare @sql long varchar;
    declare @id integer;
    
    declare @currentOwner long varchar;
    declare @currentObjName long varchar;

    declare local temporary table #d(
        data xml,
        processed integer default 0,
        currentId integer,
        currentName long varchar,
        parentId integer,
        parentName long varchar,
        id integer not null default autoincrement,
        primary key(id)
    );
    
    
    insert into #d with auto name
    select data,
           name as currentName,
           id as currentId
      from openxml(@data, '/*/*:d')
           with(data xml '@mp:xmltext', name long varchar '@name', id long varchar 'integer[@name="id"]');
           
    select top 1
           data,
           id,
           parentId,
           parentName,
           currentId,
           currentName
      into @currentData,
           @loopId,
           @currentParentId,
           @currentParentName,
           @currentId,
           @currentName
      from #d
     where processed = 0
     order by id;
 
    --message 'dbo.processRestXML loop start';
    
    while @loopId is not null loop
    
     
        set @currentOwner = left(@currentName, locate(@currentName,'.') -1);
        set @currentObjName = substr(@currentName, locate(@currentName,'.') +1);
        
        set @sql = 'insert into ' + 
                   '[' + @currentOwner + '].[' + @currentObjName + ']' + 
                   ' on existing update with auto name select '+
                    (select list('''' + value + ''' as [' + name + ']')
                            from openxml(@currentData, '/*:d/*')
                                 with(tagname long varchar '@mp:localname', name long varchar '@name', value long varchar '.') as t
                           where tagname <> 'd'
                             and exists (select *
                                           from sys.systable t join sys.sysuserperm p on t.creator = p.user_id
                                                               join sys.syscolumn c on t.table_id = c.table_id
                                          where t.table_name = @currentObjName
                                            and p.user_name = @currentOwner
                                            and c.column_name = t.name));


        --message 'dbo.processRestXML @sql = ', @sql;
           
    
        set @id = (select min(id) - 1 from #d);
        
        insert into #d with auto name
        select @id - number(*) as id,
               data,
               name as currentName,
               currentId,
               @currentName as parentName,
               @currentId as parentId
          from openxml(@currentData, '/*:d/*:d')
               with(data xml '@mp:xmltext', name long varchar '@name', currentId long varchar 'integer[@name="id"]');
    
        delete from #d
        where id = @loopId;
    
        set @loopId = null;
    
        select top 1
               data,
               id,
               parentId,
               parentName,
               currentId,
               currentName
          into @currentData,
               @loopId,
               @currentParentId,
               @currentParentName,
               @currentId,
               @currentName
          from #d
         where processed = 0
         order by id;
         
    end loop;

end
;
