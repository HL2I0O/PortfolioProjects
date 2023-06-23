--Start Data Analytics SQL Data Cleaning Project

--Get number of records:
select count(*) from NashvilleHousing;

--Get preview of first 10 records:
select * from NashvilleHousing limit 10;

--Clean coviddeaths, covidvaccinations tables (currently, columns 
--are all varchar(255) so that everything can be read in, 
--and now we want to convert to the proper types:

--Example conversion for covid deaths table:
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

--Create empty table to store converted data in:
CREATE TABLE NashvilleHousing_converted (
    UniqueID INT,
    ParcelID VARCHAR(50),
    LandUse VARCHAR(50),
    PropertyAddress VARCHAR(100),
    SaleDate DATE,
    SalePrice INT,
    LegalReference VARCHAR(50),
    SoldAsVacant VARCHAR(3),
    OwnerName VARCHAR(100),
    OwnerAddress VARCHAR(100),
    Acreage FLOAT,
    TaxDistrict VARCHAR(50),
    LandValue INT,
    BuildingValue INT,
    TotalValue INT,
    YearBuilt INT,
    Bedrooms INT,
    FullBath INT,
    HalfBath INT
);

--Convert data types and store in empty table created above:
INSERT INTO NashvilleHousing_converted
SELECT 
    CONVERT(COALESCE(NULLIF(TRIM(UniqueID), ''), '0'), UNSIGNED),
    ParcelID,
    LandUse,
    PropertyAddress,
    STR_TO_DATE(SaleDate, '%Y-%m-%d %H:%i:%s'),
    CONVERT(COALESCE(NULLIF(TRIM(SalePrice), ''), '0'), UNSIGNED),
    LegalReference,
    SoldAsVacant,
    OwnerName,
    OwnerAddress,
    CONVERT(COALESCE(NULLIF(TRIM(Acreage), ''), '0'), DECIMAL(10,2)),
    TaxDistrict,
    CONVERT(COALESCE(NULLIF(TRIM(LandValue), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(BuildingValue), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(TotalValue), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(YearBuilt), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(Bedrooms), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(FullBath), ''), '0'), UNSIGNED),
    CONVERT(COALESCE(NULLIF(TRIM(HalfBath), ''), '0'), UNSIGNED)
FROM NashvilleHousing;

select count(*) from NashvilleHousing_converted;
select * from NashvilleHousing_converted limit 10;

--Query 1: Change Date format (already converted):
select SaleDate
from NashvilleHousing_converted 
limit 10;

--Query 2: Create new column as datetime 
ALTER TABLE NashvilleHousing_converted
ADD SaleDate_Dt DATETIME;

UPDATE NashvilleHousing_converted
SET SaleDate_Dt = STR_TO_DATE(SaleDate, '%Y-%m-%d %H:%i:%s');

--Query 3: Populate Property Address column
select PropertyAddress
from NashvilleHousing_converted 
where PropertyAddress is null
limit 10;

select *
from NashvilleHousing_converted 
order by ParcelID
limit 10;

--The 'NashvilleHousing_converted' table can indeed have multiple rows with the same 'parcelid' value. 
--These rows represent different transactions or data points related to the same parcel of land.
--The self join (below) operation is used to compare rows within each 'parcelid' group. 
--Specifically, it's used to find rows where 'propertyaddress' is missing (NULL) in one row but present in another row of the same 'parcelid' group.
--The IFNULL(a.propertyaddress, b.propertyaddress) function then fills in the missing 'propertyaddress' values in table 'a' with the 
--corresponding non-missing 'propertyaddress' values from table 'b'. This is done for each 'parcelid' group.
--So, in essence, this operation is filling in missing 'propertyaddress' values based on other rows with the same 'parcelid' value. 
--(This is a common data cleaning operation when dealing with datasets where some values can be inferred or filled in based on other related data points):
SELECT 
    a.parcelID, 
    b.propertyaddress, 
    b.parcelid, 
    b.propertyaddress,
    IFNULL(a.propertyaddress, b.propertyaddress)
FROM 
    NashvilleHousing_converted a
JOIN 
    NashvilleHousing_converted b
ON 
    a.parcelid=b.parcelid
AND 
    a.UniqueID <> b.UniqueID
WHERE 
    a.propertyaddress IS NULL;

UPDATE 
    NashvilleHousing_converted a
JOIN 
    NashvilleHousing_converted b
ON 
    a.parcelid=b.parcelid
AND 
    a.UniqueID <> b.UniqueID
SET 
    a.propertyaddress = IFNULL(a.propertyaddress, b.propertyaddress);
--In the context of this self-join, it can be considered as a one-to-many join.
--Here's why: For a given 'parcelid' value, there can be multiple rows (i.e., the "many" side) with the same value, 
--and we're joining on that 'parcelid' to itself (i.e., the "one" side). 
--So, for each unique 'parcelid', we're joining it to all the rows that share that 'parcelid'.

--Query 3: Break Address into Individual Columns
select propertyaddress
from nashvillehousing_converted
limit 10;

SELECT SUBSTRING_INDEX(propertyaddress, ',', 1) AS address,
       TRIM(SUBSTRING_INDEX(propertyaddress, ',', -1)) AS city
FROM nashvillehousing_converted
LIMIT 10;

--update table with new columns:
alter table nashvillehousing_converted
add propertyasplitaddress varchar(255);

update nashvillehousing_converted
set propertyasplitaddress = SUBSTRING_INDEX(propertyaddress, ',', 1);

alter table nashvillehousing_converted
add propertyasplitcity varchar(255);

update nashvillehousing_converted
set propertyasplitcity = TRIM(SUBSTRING_INDEX(propertyaddress, ',', -1));

--split owneraddress as well
select owneraddress
from nashvillehousing_converted;

SELECT 
    SUBSTRING_INDEX(OwnerAddress, ',', 1) AS FirstWord,
    SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', -2), ',', 1) AS SecondWord,
    SUBSTRING_INDEX(OwnerAddress, ',', -1) AS ThirdWord
FROM nashvillehousing_converted;

alter table nashvillehousing_converted
add ownersplitaddress varchar(255);

update nashvillehousing_converted
set ownersplitaddress = SUBSTRING_INDEX(OwnerAddress, ',', 1);

alter table nashvillehousing_converted
add ownersplitcity varchar(255);

update nashvillehousing_converted
set ownersplitcity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', -2), ',', 1);

alter table nashvillehousing_converted
add ownersplitstate varchar(255);

update nashvillehousing_converted
set ownersplitstate = SUBSTRING_INDEX(OwnerAddress, ',', -1);

select * from nashvillehousing_converted limit 10;

--Query 4: Change Y, N to 'Yes', 'Sold as Vacant' (resp.)
select distinct(soldasvacant), count(soldasvacant)
from nashvillehousing_converted
group by soldasvacant
order by 2;

select soldasvacant,
       case when soldasvacant='Y' then 'Yes'
            when soldasvacant='N' then 'No'
            else soldasvacant
            end
from nashvillehousing_converted;

update nashvillehousing_converted
set soldasvacant = case when soldasvacant='Y' then 'Yes'
            when soldasvacant='N' then 'No'
            else soldasvacant
            end;

select distinct(soldasvacant), count(soldasvacant)
from nashvillehousing_converted
group by soldasvacant
order by 2;

--Query 5: remove duplicates

select count(*), count(distinct uniqueid) from nashvillehousing_converted;

--(parcelid, propertyaddress, saleprice, saledate, legalreference) 
--defines each row uniquely
with rowNumCTE as (
select *, 
       row_number() over (
       partition by parcelid, propertyaddress, 
       saleprice, saledate, legalreference
       order by uniqueid
       ) row_num
from nashvillehousing_converted
)
select * from rowNumCTE
where row_num > 1
order by propertyaddress;

--This query first identifies the rows that have duplicates (based on the columns you specified) and 
--keeps the one with the smallest uniqueid within each grouping; each grouping is uniquely defined by the 5-tuple values in
--(parcelid, propertyaddress, saleprice, saledate, legalreference)
--(can change this to keep the one with the largest uniqueid by replacing MIN(uniqueid) with MAX(uniqueid)). 
--Then the query deletes all other duplicates within each grouping, so only the first (ordered by uniqueid) row in each grouping is kept.
DELETE n1 FROM nashvillehousing_converted n1
INNER JOIN (
    SELECT parcelid, propertyaddress, saleprice, saledate, legalreference, MIN(uniqueid) min_uniqueid
    FROM nashvillehousing_converted
    GROUP BY parcelid, propertyaddress, saleprice, saledate, legalreference
    HAVING COUNT(*) > 1
) n2 ON n1.parcelid = n2.parcelid 
    AND n1.propertyaddress = n2.propertyaddress 
    AND n1.saleprice = n2.saleprice 
    AND n1.saledate = n2.saledate 
    AND n1.legalreference = n2.legalreference 
    AND n1.uniqueid > n2.min_uniqueid;

--Query 6: Delete unused columns
ALTER TABLE nashvillehousing_converted
DROP COLUMN owneraddress,
DROP COLUMN taxdistrict,
DROP COLUMN propertyaddress,
DROP COLUMN saledate_dt;
DROP COLUMN saledate_datetime;
DROP COLUMN saledateconverted;

select * from nashvillehousing_converted limit 10;

