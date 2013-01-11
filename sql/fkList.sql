create or replace procedure ar.fkList(@tableId integer)
begin

    select distinct
           u.user_name + '.' + t.table_name as entityName,
           pcol.column_name as primaryColumn,
           fcol.column_name as foreignColumn
      from sys.sysfkey fk join sys.systable t on fk.primary_table_id = t.table_id
                          join sys.sysuserperm u on u.user_id = t.creator
                          join sys.sysidx i on i.table_id =  fk.foreign_table_id and i.index_id =  fk.foreign_index_id
                          join sys.sysidxcol ic on ic.table_id  =i.table_id and ic.index_id = i.index_id
                          join sys.syscolumn fcol on fcol.table_id = fk.foreign_table_id and fcol.column_id = ic.column_id
                          join sys.syscolumn pcol on pcol.table_id = fk.primary_table_id and pcol.column_id = ic.primary_column_id
     where fk.foreign_table_id = @tableId;
     
end
;
