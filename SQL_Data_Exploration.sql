--Start Data Analytics SQL Data Exploration Project

--Get number of records in coviddeaths and covidvaccinations datasets
select count(*) from coviddeaths;
select count(*) from covidvaccinations;

--Get preview of first 10 records from each
select * from coviddeaths limit 10;
select * from covidvaccinations limit 10;

select date from coviddeaths limit 10;

--Clean coviddeaths, covidvaccinations tables (currently, columns 
--are all varchar(255) so that everything can be read in, 
--and now we want to convert to the proper types:

CREATE TABLE coviddeaths_converted AS
SELECT iso_code,
       continent, 
       location, 
       STR_TO_DATE(date, '%Y-%m-%d %H:%i:%s') as date, 
       CASE WHEN population REGEXP '^[0-9]+$' THEN CAST(population AS UNSIGNED) ELSE NULL END as population,
       CASE WHEN total_cases REGEXP '^[0-9]+$' THEN CAST(total_cases AS UNSIGNED) ELSE NULL END as total_cases, 
       CASE WHEN new_cases REGEXP '^[0-9]+$' THEN CAST(new_cases AS UNSIGNED) ELSE NULL END as new_cases, 
       CASE WHEN total_deaths REGEXP '^[0-9]+$' THEN CAST(total_deaths AS UNSIGNED) ELSE NULL END as total_deaths,
       CASE WHEN new_deaths REGEXP '^[0-9]+$' THEN CAST(new_deaths AS UNSIGNED) ELSE NULL END as new_deaths
FROM coviddeaths

CREATE TABLE covidvaccinations_converted AS
SELECT iso_code,
       continent, 
       location, 
       STR_TO_DATE(date, '%Y-%m-%d %H:%i:%s') as date, 
       CASE WHEN new_tests REGEXP '^[0-9]+$' THEN CAST(new_tests AS UNSIGNED) ELSE NULL END as new_tests,
       CASE WHEN total_tests REGEXP '^[0-9]+$' THEN CAST(total_tests AS UNSIGNED) ELSE NULL END as total_tests, 
       CASE WHEN total_vaccinations REGEXP '^[0-9]+$' THEN CAST(total_vaccinations AS UNSIGNED) ELSE NULL END as total_vaccinations, 
       CASE WHEN new_vaccinations REGEXP '^[0-9]+$' THEN CAST(new_vaccinations AS UNSIGNED) ELSE NULL END as new_vaccinations
FROM covidvaccinations;

--Query 1: Test query to make sure data is imported correctly:
select * from coviddeaths_converted order by 3,4;

select * 
from covidvaccinations_converted 
where location like '%states%'
order by 3,4;

--Query 2- Subset to data we are using:
drop view if exists subset;

create view subset as
select Location, date, total_cases, new_cases, total_deaths, population
from coviddeaths_converted
where continent is not null
order by 1,2;

--Query 3- Looking at Death Percentage of Cases:
--Shows likelihood of dying given
select distinct Location
from coviddeaths_converted
where continent is not null;

select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as death_pct
from coviddeaths_converted
where location like '%states%'
and continent is not null
order by 1,2;

drop view if exists usa;

create view usa as
select Location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as death_pct
from coviddeaths_converted
where location like '%states%'
and continent is not null
order by 1,2;

--Query 4- Looking at Infection Percentage:
select Location, date, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths_converted
where location like '%states%'
and continent is not null
order by 1,2;

--Query 4.5- date column seems to be sorted as alphanumeric, not actual date values
--Check type of date column to make sure values are actually dates:
SELECT DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS 
WHERE table_name = 'coviddeaths_converted' AND COLUMN_NAME = 'date';

-- It looks like the date column is actually text, so convert to actual date values:

SELECT STR_TO_DATE(date, '%m/%d/%Y')
FROM coviddeaths_converted
WHERE continent IS NOT NULL;


--Repeat Query 4 but with actual date values instead:
drop view if exists usa_infections_pct;

create view usa_infections_pct as
select Location, str_to_date(date, '%m/%d/%Y') as date_value, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths_converted
where location like '%states%'
and continent is not null
order by 1,date_value;

--Query 5- Countries by highest infection rates as of April 1st, 2021?
drop view if exists countries_by_infections_pct;

create view countries_by_infections_pct as
select Location, date, total_cases, population, (total_cases/population)*100 as infect_pct
from coviddeaths_converted
where date='2021-04-01'
and continent is not null
order by (total_cases/population)*100 desc;

--Query 6- Ranking of Countries by Highest Cases:
drop view if exists countries_by_infections;

create view countries_by_infections as
select Location, population, max(total_cases) as HighestInfectionCount, max((total_cases/population))*100 as infect_rate
from coviddeaths_converted
where continent is not null
group by location, population
order by infect_rate desc;

--Query 7- Ranking of Countries by Highest Death Count:
drop view if exists countries_by_deaths;

create view countries_by_deaths as
select Location, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths_converted
where continent is not null
group by location
order by TotalDeathCount desc;

--Query 7.5- Are we missing any countries where the continent column is missing data?:
select Location, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths_converted
where continent is null
group by location
order by TotalDeathCount desc;
--Great, all countries have their continent column filled in

--Query 8- Ranking of Continent by Death Count:
drop view if exists continents_by_deaths;

create view continents_by_deaths as
select Continent, max(cast(total_deaths as unsigned)) as TotalDeathCount
from coviddeaths_converted
where continent is not null
group by Continent
order by TotalDeathCount desc;

#-----------GLOBAL NUMBERS-----------

--Query 9-Get Total Cases and Deaths by Date:
drop view if exists total_cases_by_date;

create view total_cases_by_date as
select date, sum(new_cases) as total_cases, sum(new_deaths) as total_deaths, sum(new_deaths)/sum(new_cases) * 100 as death_pct
from coviddeaths_converted
where continent is not null
and total_cases > 1000
group by date
order by death_pct desc;

--Query 10- Join Covid Deaths and Vaccinations tables:
select *
from coviddeaths_converted as d
join covidvaccinations_converted as v
on d.location=v.location and
   d.date=v.date;
   
--Query 11- Looking at Total Population vs. Vaccinations:
--This query will fail; Can't use a calculated column in a further calculation-
--in this case, it is best to split up the sql query into 
--multiple intermediate steps and save the intermediate queries
--as temp tables that feed into subsequent steps:
select d.continent, d.location, d.date, d.population, v.new_vaccinations,
sum(cast(v.new_vaccinations as unsigned)) over (partition by location order by d.location, d.date) as rolling_num_people_vaccinated,
(rolling_num_people_vaccinated/polulation)*100
from coviddeaths_converted as d
join covidvaccinations_converted as v
on d.location=v.location and
   d.date=v.date
where d.continent is not null
order by d.location, d.date;

--Query 11 (Method 1)- Use CTE:
WITH PopvsVac AS (
  SELECT 
    d.continent, 
    d.location, 
    d.date, 
    d.population, 
    v.new_vaccinations,
    SUM(CAST(v.new_vaccinations AS UNSIGNED)) OVER (
      PARTITION BY d.location 
      ORDER BY d.location, d.date
    ) AS rolling_num_people_vaccinated
  FROM 
    coviddeaths_converted AS d
    JOIN covidvaccinations_converted AS v ON d.location = v.location AND d.date = v.date
  WHERE 
    d.continent IS NOT NULL
)
SELECT * FROM PopvsVac;

--Query 11 (Method 2)- Save as Temp Table instead of CTE instead:
--(there are significant differences between Temp Tables
--and CTEs- see this overview here:
--https://dba.stackexchange.com/questions/13112/whats-the-difference-between-a-cte-and-a-temp-table)
DROP TABLE IF EXISTS PercentPopulationVaccinated;

create table PercentPopulationVaccinated
(
Continent nvarchar(255), 
Location nvarchar(255), 
Date date, 
Population numeric, 
new_vaccinations numeric, 
rolling_num_people_vaccinated numeric
);

insert into PercentPopulationVaccinated
  SELECT 
    d.continent, 
    d.location, 
    d.date, 
    d.population, 
    v.new_vaccinations,
    SUM(CAST(v.new_vaccinations AS UNSIGNED)) OVER (
      PARTITION BY d.location 
      ORDER BY d.location, d.date
    ) AS rolling_num_people_vaccinated
  FROM 
    coviddeaths_converted AS d
    JOIN covidvaccinations_converted AS v ON d.location = v.location AND d.date = v.date
  WHERE 
    d.continent IS NOT NULL;
select *, (rolling_num_people_vaccinated/population)*100 
from PercentPopulationVaccinated;

--Query 11- Create View to store data for later visualizations:
DROP VIEW IF EXISTS PCTPopulationVaccinated;

CREATE VIEW PCTPopulationVaccinated AS
  SELECT 
    d.continent, 
    d.location, 
    d.date, 
    d.population, 
    v.new_vaccinations,
    SUM(CAST(v.new_vaccinations AS UNSIGNED)) OVER (
      PARTITION BY d.location 
      ORDER BY d.location, d.date
    ) AS rolling_num_people_vaccinated
  FROM 
    coviddeaths_converted AS d
    JOIN covidvaccinations_converted AS v ON d.location = v.location AND d.date = v.date
  WHERE 
    d.continent IS NOT NULL
  ORDER BY 2, 3;

Select *
from PCTPopulationVaccinated;
