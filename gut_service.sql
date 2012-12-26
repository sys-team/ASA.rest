sa_make_object 'service', 'gut'
;
alter service gut
TYPE 'RAW' 
authorization off user "ar"
--authorization on
url on
as call util.xml_for_http(ar.gut(:url));