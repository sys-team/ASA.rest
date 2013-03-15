sa_make_object 'service', 'csv'
;
alter service csv
TYPE 'RAW' 
--authorization off user "ar"
authorization on
url on
as call util.xml_for_http(ar.[csv](:url, 'basic'));