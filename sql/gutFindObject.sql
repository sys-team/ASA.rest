create or replace procedure ar.gutFindObject(
    @srcOwner long varchar,
    @srcName long varchar,
    @srcType long varchar default 'table'
)
begin
    declare @owner long varchar;
    declare @name long varchar;
    declare @type long varchar;

    select top 1
           owner,
           name,
           type
      into @owner, @name, @type
      from (select u.user_name as owner,
                   p.proc_name as name,
                   'sp' as type,
                   0 as sort1,
                   (select count(*)
                      from sys.sysprocparm
                     where proc_id = p.proc_id
                       and parm_mode_in = 'Y'
                       and parm_name in (select name from #variable)) as sort2          
              from sys.sysprocedure p join sys.sysuserperm u on p.creator = u.user_id,
                   #roles r
             where r.entity = @srcOwner + '.' + @srcName
               and u.user_name =  @srcOwner
               and locate(p.proc_name, @srcName +'_')=1
                        and not exists(select *
                                         from sys.sysprocparm
                                        where proc_id = p.proc_id
                                          and parm_mode_in = 'Y'
                                          and [default] is null
                                          and parm_name not in (select name from #variable))
             union
             select @srcOwner,
                    @srcName,
                    @srcType,
                    1,
                    0
               from #roles r
              where r.entity = @srcOwner + '.' + @srcName
             order by 4, 5 desc) as t;
             
    select @owner as objectOwner,
           @name as objectName,
           @type as objectType
    
end
;