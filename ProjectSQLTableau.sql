-- INSPECTING VALUES
SELECT * FROM [dbo].[sales_data_sample]
-- LOOKING FOR DISTINCT VALUES IN COLUMNS

SELECT DISTINCT status from [dbo].[sales_data_sample] -- Nice one to put into Tableau
SELECT DISTINCT YEAR_ID from [dbo].[sales_data_sample]
SELECT DISTINCT PRODUCTLINE from [dbo].[sales_data_sample]-- Nice one to put into Tableau
SELECT DISTINCT COUNTRY from [dbo].[sales_data_sample]-- Nice one to put into Tableau
SELECT DISTINCT TERRITORY from [dbo].[sales_data_sample]-- Nice one to put into Tableau
SELECT DISTINCT DEALSIZE from [dbo].[sales_data_sample]-- Nice one to put into Tableau

--ANALYSIS
-- LET'S STARTS BY GROUPING SALES BY PRODUCTLINE
SELECT PRODUCTLINE, SUM(SALES) AS REVENUE
FROM [dbo].[sales_data_sample]
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

--GROUPING SALES BY YEAR
SELECT YEAR_ID, SUM(SALES) AS REVENUE
FROM [dbo].[sales_data_sample]
GROUP BY YEAR_ID
ORDER BY 2 DESC

/*
OUTPUT
YEAR_ID   REVENUE
2004	4724162.59338379
2003	3516979.54724121
2005	1791486.7086792 -- In year 2005 you can see Sales is less than Year 2004,2003
FOR checking what is the issue we run queries for all 3 years
*/
SELECT DISTINCT MONTH_ID from [dbo].[sales_data_sample]
WHERE YEAR_ID = 2005
/*
MONTH_ID
1
2
3
4
5
*/

SELECT DISTINCT MONTH_ID from [dbo].[sales_data_sample]
WHERE YEAR_ID = 2003

/*

9
3
12
6
7
1
10
4
5
2
11
8
*/

SELECT DISTINCT MONTH_ID from [dbo].[sales_data_sample]
WHERE YEAR_ID = 2004
/*
OUTPUT
9
3
12
6
7
1
10
4
5
2
11
8
*/

/* AFTER THAT Found out that they only operate for 5 months in 2005 and in other years they operated for all months 
MONTH_ID
1
2
3
4
5
*/

-- REVENUE GENERATED BY DEALSIZE
select  DEALSIZE,  sum(sales) Revenue
from [dbo].[sales_data_sample]
group by  DEALSIZE
order by 2 desc

----What was the best month for sales in a specific year? How much was earned that month? 

select  MONTH_ID, sum(sales) AS Revenue, count(ORDERNUMBER) AS Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004 --change year to see the rest
group by  MONTH_ID
order by 2 desc

--- Query to see all Years in same column according to max revenue generated with frequency
/*
*********************************************************************************
SELECT YEAR_ID, MONTH_ID, SUM(sales) AS Revenue, COUNT(ORDERNUMBER) AS Frequency
FROM [dbo].[sales_data_sample]
WHERE YEAR_ID IN (2003, 2004, 2005)
GROUP BY YEAR_ID, MONTH_ID
ORDER BY Revenue DESC;
*********************************************************************************
OUTPUT 
Year    Month Revenue           Frequency
2004	11	1089048.00762939	301  AS we see the best month for sales in a specific year is NOV 2004
2003	11	1029837.66271973	296
2003	10	568290.971557617	158
2004	10	552924.250793457	159
2004	8	461501.267944336	133
2005	5	457861.06036377		120
*/

--November seems to be the month, what product do they sell in November, Classic I believe
select  MONTH_ID, PRODUCTLINE, sum(sales) Revenue, count(ORDERNUMBER) Frequency
from [dbo].[sales_data_sample]
where YEAR_ID = 2004 and MONTH_ID = 11 --change year to see the rest
group by  MONTH_ID, PRODUCTLINE
order by 3 desc

----Who is our best customer (this could be best answered with RFM)
;with rfm as 
(
	select 
		CUSTOMERNAME, 
		sum(sales) MonetaryValue,
		avg(sales) AvgMonetaryValue,
		count(ORDERNUMBER) Frequency,
		max(ORDERDATE) last_order_date,
		(select max(ORDERDATE) from [dbo].[sales_data_sample]) max_order_date,
		DATEDIFF(DD, max(ORDERDATE), (select max(ORDERDATE) from [dbo].[sales_data_sample])) Recency
	from [dbo].[sales_data_sample]
	group by CUSTOMERNAME
),
rfm_calc as
(

	select r.*,
		NTILE(4) OVER (order by Recency desc) rfm_recency,
		NTILE(4) OVER (order by Frequency) rfm_frequency,
		NTILE(4) OVER (order by MonetaryValue) rfm_monetary
	from rfm r
)
select 
	c.*, rfm_recency+ rfm_frequency+ rfm_monetary as rfm_cell,
	cast(rfm_recency as varchar) + cast(rfm_frequency as varchar) + cast(rfm_monetary  as varchar)rfm_cell_string
into #rfm
from rfm_calc c

select CUSTOMERNAME , rfm_recency, rfm_frequency, rfm_monetary,
	case 
		when rfm_cell_string in (111, 112 , 121, 122, 123, 132, 211, 212, 114, 141) then 'lost_customers'  --lost customers
		when rfm_cell_string in (133, 134, 143, 244, 334, 343, 344, 144) then 'slipping away, cannot lose' -- (Big spenders who haven�t purchased lately) slipping away
		when rfm_cell_string in (311, 411, 331) then 'new customers'
		when rfm_cell_string in (222, 223, 233, 322) then 'potential churners'
		when rfm_cell_string in (323, 333,321, 422, 332, 432) then 'active' --(Customers who buy often & recently, but at low price points)
		when rfm_cell_string in (433, 434, 443, 444) then 'loyal'
	end rfm_segment

from #rfm

--What products are most often sold together? 
--select * from [dbo].[sales_data_sample] where ORDERNUMBER =  10411


WITH ShippedOrders AS (
    SELECT ORDERNUMBER
    FROM [dbo].[sales_data_sample]
    WHERE STATUS = 'Shipped'
    GROUP BY ORDERNUMBER
    HAVING COUNT(*) = 3
)
SELECT DISTINCT s.OrderNumber, 
       STUFF((SELECT ',' + p.PRODUCTCODE
              FROM [dbo].[sales_data_sample] p
              WHERE p.ORDERNUMBER = s.ORDERNUMBER
              FOR XML PATH('')), 1, 1, '') AS ProductCodes
FROM [dbo].[sales_data_sample] s
WHERE EXISTS (
    SELECT 1
    FROM ShippedOrders
    WHERE ShippedOrders.ORDERNUMBER = s.ORDERNUMBER
)
ORDER BY 2 DESC;
