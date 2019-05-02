
--Convert date strings to datetime.
UPDATE BavarianLodge.dbo.holidays
SET Date = REPLACE(Date, Date, CAST(Date AS datetime));

UPDATE BavarianLodge.dbo.data
SET Date = REPLACE(Date, Date, CAST(Date AS datetime));


--Create intermediate table with holidays.
SELECT
	b.Friendly AS holiday_friendly,
	b.[Holiday Code] AS holiday_code,
	b.Type AS holiday_type,
	a.*
INTO BavarianLodge.dbo.temp1
FROM BavarianLodge.dbo.data AS a
LEFT JOIN BavarianLodge.dbo.holidays AS b
ON a.date = b.Date;

--Check output--
SELECT TOP 100 * FROM BavarianLodge.dbo.temp1;

--Create holiday flag column
--ALTER TABLE BavarianLodge.dbo.temp1
--	ADD is_holiday AS (CASE WHEN holiday_code IS NOT NULL THEN '1' ELSE '0' END);

--Check output
--SELECT TOP 100* FROM BavarianLodge.dbo.temp1;

--Create holiday +/- date ranges
SELECT date
INTO BavarianLodge.dbo.temp2
FROM BavarianLodge.dbo.temp1
WHERE ishol = '1';

 SELECT date
 INTO BavarianLodge.dbo.hol7
 FROM BavarianLodge.dbo.temp1
 WHERE date IN (
	(SELECT DATEADD(day, 1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 4, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -4, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 5, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -5, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 6, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -6, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 7, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -7, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -7, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	 SELECT date FROM BavarianLodge.dbo.temp2);

SELECT date
 INTO BavarianLodge.dbo.hol5
 FROM BavarianLodge.dbo.temp1
 WHERE date IN (
	(SELECT DATEADD(day, 1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 4, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -4, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 5, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -5, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	 SELECT date FROM BavarianLodge.dbo.temp2);

SELECT date
 INTO BavarianLodge.dbo.hol3
 FROM BavarianLodge.dbo.temp1
 WHERE date IN (
	(SELECT DATEADD(day, 1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -1, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -2, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, 3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	(SELECT DATEADD(day, -3, date) FROM BavarianLodge.dbo.temp2) UNION ALL
	 SELECT date FROM BavarianLodge.dbo.temp2);
	 
--Add hol3, hol5 & hol7 to temp5--

SELECT
	*,
	hol3 = CASE WHEN date IN (SELECT date FROM BavarianLodge.dbo.hol3) THEN '1' ELSE '0' END,
	hol5 = CASE WHEN date IN (SELECT date FROM BavarianLodge.dbo.hol5) THEN '1' ELSE '0' END,
	hol7 = CASE WHEN date IN (SELECT date FROM BavarianLodge.dbo.hol7) THEN '1' ELSE '0' END
	INTO BavarianLodge.dbo.temp3
	FROM BavarianLodge.dbo.temp1;

--Create holiday weekend column
ALTER TABLE BavarianLodge.dbo.temp3
	ADD holwknd AS (CASE WHEN hol5 = '1' AND dowc IN('6','7','1') THEN '1' ELSE '0' END);

SELECT CONVERT(date,GETDATE(),126) FROM BavarianLodge.dbo.temp3;

SELECT * FROM BavarianLodge.dbo.temp3;




----------------------------------------------------------------------------------------------------------------------- ARCHIVE -----------------------------------------------------------------------------------------------------------------------

--SELECT
--	'1' AS hol7,
--	*
--INTO BavarianLodge.dbo.temp4
--FROM BavarianLodge.dbo.temp1 WHERE date IN (SELECT date FROM BavarianLodge.dbo.temp3);

--Add holiday_7 column to temp5

--SELECT
--	a.*,
--	hol7 = CASE WHEN b.hol7 = '1' THEN b.hol7 ELSE '0' END
--	INTO BavarianLodge.dbo.temp5
--	FROM BavarianLodge.dbo.temp1 AS a
--	LEFT JOIN BavarianLodge.dbo.temp4 AS b
--	ON a.date = b.date;