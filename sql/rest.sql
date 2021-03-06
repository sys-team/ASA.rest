create or replace function ar.rest(
    @url long varchar,
    @authType long varchar default 'basic',
    @code long varchar default isnull(nullif(replace(http_header('Authorization'), 'Bearer ', ''),''), http_variable('authorization:')),
    @pageSize integer default coalesce(nullif(http_header('page-size'),''), http_variable('page-size:'),10),
    @pageNumber integer default coalesce(nullif(http_header('page-number'),''), http_variable('page-number:'),1),
    @isolationLevel long varchar default coalesce(nullif(http_header('isolation-level'),''), http_variable('isolation-level:'), '1'),
    @ETag STRING default util.HTTPVariableOrHeader ('if-none-match')
)
returns xml
begin
    declare @response xml;
    declare @error long varchar;
    declare @errorCode long varchar;
    declare @entity long varchar;
    declare @action long varchar;
    declare @cts datetime;
    declare @varName long varchar;
    declare @maxLogLength integer;
    declare @parentEntity long varchar;

    declare local temporary table #variable(
        name long varchar,
        value long varchar,
        operator varchar(64) default '='
    );

    declare local temporary table #ids(
        xid GUID,
        primary key(xid)
    );

    if varexists('@xid') = 0 then create variable @xid GUID end if;

    if isnull(http_body(), '')  <> '' then

        insert into #ids with auto name
        select xid
        from openxml(http_body(), '/*:request/*:d')
            with(xid STRING '@xid')

    end if;

    set @cts = now();
    set @xid = newid();

    insert into ar.log with auto name
    select
        @xid as xid,
        @url as url,
        @code as code,
        isnull(
            util.HTTPVariableOrHeader('x-real-ip'),
            connection_property('ClientNodeAddress')
        ) as callerIP
    ;

    select action,
           entity,
           parentEntity
      into @action, @entity, @parentEntity
      from openstring(value @url)
           with (action long varchar, entity long varchar, id long varchar, parentEntity long varchar)
           option(delimited by '/') as t
    ;

    if varexists('@roles') = 0 then create variable @roles xml end if;
    if varexists('@isDba') = 0 then create variable @isDba integer end if;
    if varexists('@rowcount') = 0 then create variable @rowcount integer end if;

    if @authType <> 'basic' then
        set @roles = uac.UOAuthAuthorize(@code);
        if varexists('@UOAuthAccessToken') = 0 then create variable @UOAuthAccessToken long varchar end if;
        set @UOAuthAccessToken = @code;

        update ar.log
           set account = (
               select account
               from uac.token
               where token = @code
           )
        where xid = @xid;
    end if;

    -- http variables
    insert into #variable with auto name
    select
        name, value
        from util.httpVariables()
    ;

    update ar.log
        set variables = (select list(name +'='+value, '&') from #variable)
        where xid = @xid
    ;



    -- entity id & entity type
    if varexists('@entityId') = 0 then create variable @entityId integer end if;
    if varexists('@entityType') = 0 then create variable @entityType varchar(128) end if;
    if varexists('@newsNextOffset') = 0 then create variable @newsNextOffset varchar(128) end if;

    select entityId,
           entityType
      into @entityId, @entityType
      from ar.entityIdAndType(@entity);

    -- isolation level set
    --message 'ar.rest @isolationLevel = ', @isolationLevel;
    case @isolationLevel
        when '0' then
            set temporary option isolation_level = 0;
        when '1' then
            set temporary option isolation_level = 1;
        when '2' then
            set temporary option isolation_level = 2;
        when '3' then
            set temporary option isolation_level = 3;
    end case;

    -- forbidden chars
    if exists (select *
                 from #variable
                where ar.checkForbiddenChars(name) = 1
                   or ar.checkForbiddenChars(value) = 1)
       or ar.checkForbiddenChars(@url) = 1 then

        set @response = xmlelement('error', 'Forbidden chracter detected');

    -- check @roles
    elseif not exists(select *
                    from openxml(@roles,'/*:response/*:roles/*:role')
                         with(code long varchar '*:code')
                   where code = 'authenticated') and @authType <> 'basic' then

        set @response = xmlelement('error', 'Not authorized');
        CALL dbo.sa_set_http_header( '@HttpStatus', '403' );
    else
        -- DBA authority check
        if @authType <> 'basic' then
            set @isDba = (select count(*)
                            from openxml(@roles,'/*:response/*:roles/*:role')
                                 with(code long varchar '*:code', data long varchar '*:data')
                           where code = @@servername + '.' + db_name()
                             and data = 'dba');

            if isnull(util.getUserOption('uac.emailAuth'),'0') = '1' then
                set @isDba = 1;
            end if;
        else
            set @isDba = 1;
        end if;

        call ar.parseVariables();

        case @action
            when 'get' then
                set @response = ar.getQuery(@url);
            when 'news' then
                set @response = ar.news(@url);
            when 'testData' then
                set @response = ar.testData(@url);
            when 'put' then
                set @response = ar.put(@url);
            when 'make' then
                set @response = ar.make(@url);
            when 'addElement' then
                set @response = ar.addElement(@url);
            when 'link' then
                set @response = ar.link(@url);
            when 'aggregate' then
                set @response = ar.getQuery(@url, 1);
        end case;

    end if;

    with xmldataset as (
        select * from openxml(xmlelement('root',@response), '/root/d') with(
            id STRING '*[@name="id"]', ts timestamp '@nanoTs', rowcount integer '*[@name="__rowcount__"]'
        )
    ) select xmlelement('response',
            xmlattributes(
                'https://github.com/sys-team/ASA.rest' as "xmlns",
                @xid as "xid",
                now() as "ts",
                @cts as "cts",
                if @rowcount is null and @action <> 'aggregate' then @pageSize endif as "page-size",
                if @rowcount is null and @action <> 'aggregate' then @pageNumber endif as "page-number",
                if @rowcount is null and @action <> 'aggregate' then count (*) endif as "page-row-count",
                @@servername as "servername",
                db_name() as "dbname",
                property('machinename') as "host",
                @newsNextOffset as "news-next-offset",
                isnull(@parentEntity,@entity) as "title",
                if util.HTTPVariableOrHeader ('if-none-match') is not null then
                    (select top 1 ar.etagFromTsAndId (ts, id, ar.versionFromETag(@ETag))
                        from xmldataset
                        order by ts desc, cast(id as bigint) desc
                    )
                endif as "ETag",
                if @rowcount is not null then @rowcount endif as "rows-affected"
            ),
        @response
    )
        into @response
        from xmldataset
    ;

    set @maxLogLength = isnull(nullif(util.getUserOption('ar.maxLogLength'),''),65536);

    update ar.log set response =
        if length(@response) > @maxLogLength then
            xmlelement('response','<![CDATA[' + left(@response,@maxLogLength) + ']]>')
        else
            @response
        endif
    where xid = @xid;

    return @response;

    exception
        when others then

            set @error = errormsg();
            if @error like 'RAISERROR executed: %' then
                set @errorCode =  trim(substring(@error, locate(@error,'RAISERROR executed: ') + length('RAISERROR executed: ')));
            end if;

            rollback;

            set @response = xmlelement('response',
                xmlattributes(
                    'https://github.com/sys-team/ASA.rest' as "xmlns",now() as "ts"
                ),
                xmlelement('error', xmlattributes(@errorCode as "code"), @error)
            );

            update ar.log
               set response = @response
            where xid = @xid;

            return @response;

end;
