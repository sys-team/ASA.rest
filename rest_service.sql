drop service rest
;
create service rest
TYPE 'RAW' 
--authorization off user "ar"
authorization on
url on
as call util.xml_for_http(ar.rest(:url));