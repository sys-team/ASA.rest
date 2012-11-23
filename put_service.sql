drop service put
;
create service put
TYPE 'RAW' 
AUTHORIZATION OFF USER "ar"
url on
as call util.xml_for_http(ar.put(:url));