sa_make_object 'event', 'aws_ar_monitoring_event';

drop event aws_ar_monitoring_event;

create event aws_ar_monitoring_event
handler begin

    declare @dateB timestamp;
    declare @now timestamp;

    if EVENT_PARAMETER('NumActive') <> '1' then
        return;
    end if;

    set @now = now();
    set @dateB = dateadd(minute, -1, @now);

    for c as c cursor for

        select

            @now as [Timestamp],
            count (distinct a.id) [Users Count],
            count (*) [Requests Count],

            aws.putMetricData (
              'AR Requests Count',
              [Requests Count],
              [Timestamp]
            ) as [putRequestsCountResponse],
            aws.putMetricData (
              'AR Users Count',
              [Users Count],
              [Timestamp]
            ) as [putUsersCountResponse]

        from ar.log
          join uac.token t on t.token = log.code
          join uac.account a on a.id = t.account
        where log.ts between @dateB and @now

    do message

        current database, '.aws_ar_monitoring_event',
        ' put: { ',
          'Users:', [Users Count],
          ', Requests:', [Requests Count],
        ' }',
        ' for ts: ''', [Timestamp], '''',
        ' responses: [',
          [putRequestsCountResponse], ', ', [putUsersCountResponse],
        ']'

        debug only

    end for;

end;

alter event aws_ar_monitoring_event add SCHEDULE heartbeat
    start time '00:01:00'
    every 1 minutes
;

alter event aws_ar_monitoring_event
    disable
;
