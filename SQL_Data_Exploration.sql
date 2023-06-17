#Start Data Analytics SQL Data Exploration Project

#Get number of records in coviddeaths and covidvaccinations datasets
select count(*) from coviddeaths;

#Get preview of first 10 records from each
select * from coviddeaths limit 10;

select * from covidvaccinations limit 10;

#Query 1: Test query to make sure data is imported correctly:
select * from coviddeaths order by 3,4


#