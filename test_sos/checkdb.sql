.header on
select latest_frame, guid, prog_name from tblpubs;
select count(distinct name) from tbldata;
select count(*) from tblvals;
select count(*) from viewcombined;

#select frame,prog_name,comm_rank,value_name,value from viewcombined where frame = 12 order by prog_name, comm_rank, value_name limit 10;
#select distinct name from tbldata;
