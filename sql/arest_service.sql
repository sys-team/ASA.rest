sa_make_object 'service', 'arest'
;
alter service arest
TYPE 'RAW' 
authorization off user "ar"
--authorization on
url on
as call util.xml_for_http(ar.rest(:url,'uoauth'));