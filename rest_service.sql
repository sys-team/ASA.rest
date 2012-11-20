drop service rest
;
create service rest
TYPE 'RAW' 
AUTHORIZATION OFF USER "ar"
url on
as call util.xml_for_http(ar.rest(:url));