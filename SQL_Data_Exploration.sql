#Start Data Analytics SQL Data Exploration Project

#Get number of records in coviddeaths and covidvaccinations datasets
select count(*) from coviddeaths;

#Get preview of first 10 records from each
select * from coviddeaths limit 10;

select * from covidvaccinations limit 10;

#Query 1: Test query to make sure data is imported correctly:
select * from coviddeaths order by 3,4;

select * from covidvaccinations order by 3,4;

#Query 2- Subset to data we are using:
drop view if exists subset;

create view subset as
select Location, date, total_cases, new_cases, total_deaths, population
from coviddeaths
where continent is not null
order by 1,2;

#Query 3- Looking at Death Percentage of Cases:
#Shows likelihood of dying given
select distinct Location
from coviddeaths
where continent is not null;

select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as death_pct
from coviddeaths
where location like '%states%'
and continent is not null
order by 1,2;

drop view if exists vietnam;

create view vietnam as
select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as death_pct
from coviddeaths
where location like '%ietna%'
and continent is not null
order by 1,2;

#Query 4- Looking at Infection Percentage:
select Location, date, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths
where location like '%ietnam%'
and continent is not null
order by 1,2;

#Query 4.5- date column seems to be sorted as alphanumeric, not actual date values
#Check type of date column to make sure values are actually dates:
SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS 
  WHERE table_name = 'coviddeaths' AND COLUMN_NAME = 'date';
#It looks like the date column is actually text, so convert to actual date values:
select str_to_date(d,.ate, '%m/%d/%Y')
from coviddeaths
where continent is not null;

#Repeat Query 4 but with actual date values instead:
drop view if exists vietnam_infections_pct;

create view vietnam_infections_pct as
select Location, str_to_date(date, '%m/%d/%Y') as date_value, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths
where location like '%ietnam%'
and continent is not null
order by 1,date_value;

#Query 5- Countries by highest infection rates as of April 1st, 2021?
drop view if exists countries_by_infections_pct;

create view countries_by_infections_pct as
select Location, str_to_date(date, '%m/%d/%Y') as date_value, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths
where str_to_date(date, '%m/%d/%Y')='2021-04-01'
and continent is not null
order by (total_cases/population)*100 desc;

#Query 6- Ranking of Countries by Highest Cases:
drop view if exists countries_by_infections;

create view countries_by_infections as
select Location, population, max(total_cases) as HighestInfectionCount, max((total_cases/population))*100 as infect_rate
from coviddeaths
where continent is not null
group by location, population
order by infect_rate desc;

#Query 7- Ranking of Countries by Highest Death Count:
drop view if exists countries_by_deaths;

create view countries_by_deaths as
select Location, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths
where continent is not null
group by location
order by TotalDeathCount desc;

#Query 7.5- Are we missing any countries where the continent column is missing data?:
select Location, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths
where continent is null
group by location
order by TotalDeathCount desc;
#Great, all countries have their continent column filled in

#Query 8- Ranking of Continent by Death Count:
drop view if exists continents_by_deaths;

create view continents_by_deaths as
select Continent, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths
where continent is not null
group by Continent
order by TotalDeathCount desc;

#-----------GLOBAL NUMBERS-----------

#Query 9-Get Total Cases and Deaths by Date:
drop view if exists total_cases_by_date;

create view total_cases_by_date as
select date, str_to_date(date, '%m/%d/%Y') as date_value, sum(new_cases) as total_cases, sum(new_deaths) as total_deaths, sum(new_deaths)/sum(new_cases) * 100 as death_pct
from coviddeaths
where continent is not null
and total_cases > 1000
group by date
order by death_pct desc;

#Query 10- Join Covid Deaths and Vaccinations tables:
select *
from coviddeaths as d
join covidvaccinations as v
on d.location=v.location and
   d.date=v.date;
   
#Query 11- Looking at Total Population vs. Vaccinations:
select d.continent, d.location, d.date, str_to_date(d.date, '%m/%d/%Y') as date_value, d.population, v.new_vaccinations,
sum(cast(v.new_vaccinations as unsigned)) over (partition by location order by d.location, d.date) as rolling_num_people_vaccinated,
#This query will fail; Can't use a calculated column in a further calculation-
#in this case, it is best to split up the sql query into 
#multiple intermediate steps and save the intermediate queries
#as temp tables that feed into subsequent steps:
(rolling_num_people_vaccinated/polulation)*100
from coviddeaths as d
join covidvaccinations as v
on d.location=v.location and
   d.date=v.date
where d.continent is not null
order by d.location, date_value;

#Query 11 (Method 1)- Use CTE:
With PopvsVac (Continent, Location, Date, date_value, Population, new_vaccinations, rolling_num_people_vaccinated)
as (
select d.continent, d.location, d.date, str_to_date(d.date, '%m/%d/%Y') as date_value, d.population, v.new_vaccinations,
sum(cast(v.new_vaccinations as unsigned)) over (partition by location order by d.location, d.date) as rolling_num_people_vaccinated
from coviddeaths as d
join covidvaccinations as v
on d.location=v.location and
   d.date=v.date
where d.continent is not null
)
#After this intermediate query which creates the 
#'rolling_num_people_vaccinated' column is saved as a CTE,
#we can now reference the calculated 
#'rolling_num_people_vaccinated' column in further calculations:
select *, (rolling_num_people_vaccinated/population)*100 
from PopvsVac;

#Query 11 (Method 2)- Save as Temp Table instead of CTE instead:
#(there are significant differences between Temp Tables
#and CTEs- see this overview here:
#https://dba.stackexchange.com/questions/13112/whats-the-difference-between-a-cte-and-a-temp-table)
DROP TABLE IF EXISTS PercentPopulationVaccinated;

create table PercentPopulationVaccinated
(
Continent nvarchar(255), 
Location nvarchar(255), 
Date date, 
date_value datetime, 
Population numeric, 
new_vaccinations numeric, 
rolling_num_people_vaccinated numeric
);

insert into PercentPopulationVaccinated
select d.continent, d.location, STR_TO_DATE(d.date, '%m/%d/%y') as Date, STR_TO_DATE(d.date, '%m/%d/%y') as date_value, d.population, v.new_vaccinations,
sum(cast(v.new_vaccinations as unsigned)) over (partition by location order by d.location, STR_TO_DATE(d.date, '%m/%d/%y')) as rolling_num_people_vaccinated
from coviddeaths as d
join covidvaccinations as v
on d.location=v.location and
   STR_TO_DATE(d.date, '%m/%d/%y')=STR_TO_DATE(v.date, '%m/%d/%y')
where d.continent is not null and (v.new_vaccinations REGEXP '^-?[0-9]+$' OR v.new_vaccinations IS NULL);

select *, (rolling_num_people_vaccinated/population)*100 
from PercentPopulationVaccinated;

#Query 11- Create View to store data for later visualizations:
DROP VIEW IF EXISTS PercentPopulationVaccinated;

CREATE VIEW PercentPopulationVaccinated AS
SELECT d.continent, d.location, STR_TO_DATE(d.date, '%m/%d/%y') as Date, STR_TO_DATE(d.date, '%m/%d/%y') as date_value, d.population, v.new_vaccinations,
SUM(CAST(v.new_vaccinations AS UNSIGNED)) OVER (PARTITION BY location ORDER BY d.location, STR_TO_DATE(d.date, '%m/%d/%y')) as rolling_num_people_vaccinated
FROM coviddeaths AS d
JOIN covidvaccinations AS v
ON d.location=v.location AND
   STR_TO_DATE(d.date, '%m/%d/%y')=STR_TO_DATE(v.date, '%m/%d/%y')
WHERE d.continent IS NOT NULL AND (v.new_vaccinations REGEXP '^-?[0-9]+$' OR v.new_vaccinations IS NULL)
ORDER BY 2, 3;

Select *
from PercentPopulationVaccinated;
