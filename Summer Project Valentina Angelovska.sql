USE master
GO

IF EXISTS (
SELECT * FROM sys.databases
WHERE name = 'SummerProject')
DROP DATABASE SummerProject
GO

CREATE DATABASE SummerProject
GO

USE SummerProject
GO

CREATE TABLE dbo.SeniorityLevel (
ID int identity(1,1) NOT NULL,
Name nvarchar(100) NOT NULL,
CONSTRAINT PK_SeniorityLevel PRIMARY KEY CLUSTERED 
(
ID ASC
))
GO

INSERT INTO dbo.SeniorityLevel (Name)
VALUES ('Junior'), ('Intermediate'), ('Senior'), ('Lead'), ('Project Manager'), ('Division Manager'), ('Office Manager'), ('CEO'), ('CTO'), ('CIO')
GO

CREATE TABLE dbo.Location (
ID int identity(1,1) NOT NULL,
CountryName nvarchar(100) NULL,
Continent nvarchar(100) NULL,
Region nvarchar(100) NULL,
CONSTRAINT PK_Location PRIMARY KEY CLUSTERED
(
ID ASC
))
GO

INSERT INTO dbo.Location (CountryName,Continent,Region)
SELECT CountryName,Continent,Region
FROM WideWorldImporters.Application.Countries 
GO

CREATE TABLE dbo.Department (
ID int identity(1,1) NOT NULL,
Name nvarchar(100) NOT NULL,
CONSTRAINT PK_Department PRIMARY KEY CLUSTERED
(
ID ASC
))
GO

INSERT INTO dbo.Department (Name)
VALUES ('Personal Banking & Operations'), ('Digital Banking Department'), ('Retail Banking & Marketing Department'),
	   ('Wealth Management & Third Party Products'), ('International Banking Division & DFB'), ('Treasury'),
	   ('Information Technology'), ('Corporate Communications'), ('Support Services & Branch Expansion'), ('Human Resources')
GO

CREATE TABLE dbo.Employee (
ID int identity(1,1) NOT NULL,
FirstName nvarchar(100) NOT NULL,
LastName nvarchar(100) NOT NULL,
SeniorityLevelID int NOT NULL,
DepartmentID int NOT NULL,
LocationID int NOT NULL,
CONSTRAINT PK_Employee PRIMARY KEY CLUSTERED
(
ID ASC
))
GO

INSERT INTO dbo.Employee (FirstName,LastName,SeniorityLevelID,DepartmentID,LocationID)
SELECT (LEFT(FullName,charindex(' ',FullName,0)-1)) as FirstName, (SUBSTRING(FullName,charindex(' ',FullName,0)+1,LEN(FullName))) as LastName,
1,1,1 -- bid na slikata bese da se notnull ova go staviv kolku da ima podatok podolu pravam update
FROM WideWorldImporters.Application.People 
GO

--Seniority Level ID Column
ALTER TABLE dbo.Employee WITH CHECK
ADD CONSTRAINT FK_Employee_SeniorityLevel FOREIGN KEY (SeniorityLevelID)
REFERENCES dbo.SeniorityLevel (ID)
GO

UPDATE e
SET e.SeniorityLevelID = sl.ID 
FROM dbo.Employee e
INNER JOIN dbo.SeniorityLevel sl on sl.ID = (e.ID % 10 +1) --+1 za da nema nuli 
GO

-- DepartmentID Column
ALTER TABLE dbo.Employee WITH CHECK
ADD CONSTRAINT FK_Employee_Department FOREIGN KEY (DepartmentID)
REFERENCES dbo.Department (ID)
GO

UPDATE e
SET e.DepartmentID = d.ID 
FROM dbo.Employee e
INNER JOIN dbo.Department d on d.ID = (e.ID % 10 +1)
GO

--LocationID Column
ALTER TABLE dbo.Employee WITH CHECK
ADD CONSTRAINT FK_Employee_Location FOREIGN KEY (LocationID)
REFERENCES dbo.Location (ID)
GO

; WITH cte AS
(
SELECT e.LocationID as LocationID, NTILE(190) OVER (ORDER BY ID ASC) as LID
FROM
dbo.Employee e
)
UPDATE cte
SET cte.LocationID = cte.LID
GO

-- Salary Table
CREATE TABLE dbo.Salary (
ID bigint identity(1,1) NOT NULL,
EmployeeId int NOT NULL,
Month smallint NOT NULL,
Year smallint NOT NULL,
GrossAmount decimal(18,2) NOT NULL,
NetAmount decimal(18,2) NOT NULL,
RegularWorkAmount decimal(18,2) NOT NULL,
BonusAmount decimal(18,2) NOT NULL,
OvertimeAmount decimal(18,2) NOT NULL,
VacationDays smallint NOT NULL,
SickLeaveDays smallint NOT NULL,
CONSTRAINT PK_Salary PRIMARY KEY CLUSTERED
(
ID ASC
))
GO

ALTER TABLE dbo.Salary WITH CHECK 
ADD CONSTRAINT FK_Salary_Employee FOREIGN KEY (EmployeeID) 
REFERENCES dbo.Employee (ID)
GO

CREATE TABLE #Month (Month int)
GO
INSERT INTO #Month VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),(12)
GO

CREATE TABLE #Year (Year int)
GO
INSERT INTO #Year VALUES (2001),(2002),(2003),(2004),(2005),(2006),(2007),(2008),(2009),(2010),
						 (2011),(2012),(2013),(2014),(2015),(2016),(2017),(2018),(2019),(2020)
GO
 
;WITH cte1 AS (
SELECT e.ID AS EmployeeID, m.Month AS Month, y.Year AS Year, 
ABS(CHECKSUM(NEWID())) % 30001 + 30000 AS GrossAmount
FROM dbo.Employee e 
cross apply #Month m
cross apply #Year y 
) , cte2 AS (
SELECT *, 
cte1.GrossAmount * 0.9 AS NetAmount, 
(cte1.GrossAmount * 0.9)*0.8 AS RegularWorkAmount
FROM cte1 )

INSERT INTO dbo.Salary (EmployeeId,Month,Year,GrossAmount,NetAmount,RegularWorkAmount,BonusAmount,OvertimeAmount,VacationDays,SickLeaveDays)
SELECT EmployeeID, Month, Year, GrossAmount, NetAmount, RegularWorkAmount,
CASE WHEN Month%2 <> 0 THEN (NetAmount - RegularWorkAmount) ELSE 0.00 END as BonusAmount,
CASE WHEN Month%2 = 0 THEN (NetAmount - RegularWorkAmount) ELSE 0.00 END as OvertimeAmount, 
0, 0 -- isto kako pogore not null barase da bidat spored dijagramot, podolu pravam update
FROM cte2
GO

--Vacation Days
UPDATE s 
SET VacationDays = 10 
FROM dbo.Salary s
WHERE Month = 7 OR Month = 12
GO
-- random vacation days
UPDATE dbo.Salary SET vacationDays = vacationDays + (EmployeeId % 2)
WHERE (employeeId + MONTH+ year)%5 = 1
GO

--SickLeaveDays
UPDATE dbo.salary SET SickLeaveDays = EmployeeId%8, vacationDays = vacationDays + (EmployeeId % 3)
WHERE  (employeeId + MONTH+ year)%5 = 2
GO


--If everything is done as expected the following query should return 0 rows:
--select * from dbo.salary 
--where NetAmount <> (regularWorkAmount + BonusAmount + OverTimeAmount)

-- CHECK FOR VACATIONDAYS BETWEEN 20 and 30
--select employeeid, year, SUM(vacationdays) as VacationDays
--from dbo.Salary
--group by EmployeeId,Year
--having sum(Vacationdays) between 20 and 30
--order by EmployeeId,Year


--Database Diagram ne se zacuvuva bidejki imam na pochetok drop database if exists, ama so samoto klikanje na new database samata se generira avtomatski 
-- poradi kluchevite koi gi imam postaveno

--select * from dbo.Employee
--select * from dbo.Salary where EmployeeId = 1 order by year
--select * from dbo.SeniorityLevel
--select * from dbo.Department
--select * from dbo.Location