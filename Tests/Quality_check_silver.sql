SELECT *
FROM silver.crm_cust_info

--check for duplicates :

SELECT cst_id, 
	COUNT(*)
FROM silver.crm_cust_info
GROUP BY 1
HAVING COUNT(*) > 1 OR cst_id IS NULL


-- Filter out duplicates 
SELECT *
FROM(
		SELECT *,
		RANK() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)
		AS flag_last
	FROM silver.crm_cust_info
)

WHERE flag_last = 1 AND cst_id IS NOT NULL


-- check for unwanted spaces on string values
SELECT cst_firstname, cst_lastname, cst_marital_status
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
OR cst_lastname != TRIM(cst_lastname)
OR cst_gndr != TRIM(cst_gndr)

-- Trim spaces using the query where duplicates were filtered out:
SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname, 
	TRIM(cst_lastname) AS cst_lastname, 
	cst_marital_status,
	cst_gndr, 
	cst_create_date
FROM (
		SELECT *,
		RANK() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)
		AS flag_last
	FROM bronze.crm_cust_info
	
)

--Data standardization and consistency
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info
--coverted gender values into full words for clarity

SELECT DISTINCT cst_marital_status
FROM bronze.crm_cust_info

-------------------------------------- CRM_PRD_INFO ---------------------

SELECT *
FROM bronze.crm_prd_info

--checking for nulls and duplicates

SELECT prd_id,
	COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*)> 1 OR prd_id IS NULL

--- extracting data into a new column, and filtering out unmatched data, comparing with erp_cat table
SELECT 
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	SUBSTRING(prd_key, 7,LENGTH(prd_key)) AS prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') NOT IN
(SELECT DISTINCT id from bronze.erp_px_cat_g1v2)

-- extract last part from prd_key column as prd_key and compare with sls_prd_key
SELECT 
	prd_id,
	prd_key,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	SUBSTRING(prd_key, 7,LENGTH(prd_key)) AS prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
FROM bronze.crm_prd_info
WHERE SUBSTRING(prd_key, 7,LENGTH(prd_key)) NOT IN
(SELECT sls_prd_key FROM bronze.crm_sales_details)

--Check for whitespace
SELECT 
	prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- check for NULLs and negative numbers
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

--Replace Nulls with 0
SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	SUBSTRING(prd_key, 7,LENGTH(prd_key)) AS prd_key,
	prd_nm,
	COALESCE(prd_cost,0) AS prd_cost,
	CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
		WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
		WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,
	prd_start_dt,
	prd_end_dt
FROM bronze.crm_prd_info

-- Fix prd_start_dt and prd_end_dt where end date is less than start date
SELECT 
	prd_id,
	REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
	SUBSTRING(prd_key, 7,LENGTH(prd_key)) AS prd_key,
	prd_nm,
	COALESCE(prd_cost,0) AS prd_cost,
	CASE WHEN UPPER(TRIM(prd_line)) = 'M' THEN 'Mountain'
		WHEN UPPER(TRIM(prd_line)) = 'R' THEN 'Road'
		WHEN UPPER(TRIM(prd_line)) = 'S' THEN 'Other Sales'
		WHEN UPPER(TRIM(prd_line)) = 'T' THEN 'Touring'
		ELSE 'n/a'
	END AS prd_line,
	prd_start_dt,
	LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)-1 AS prd_end_dt
FROM bronze.crm_prd_info

-------------------------------------- CRM_SALES_DETAILS ---------------------

SELECT
	sls_order_num, -- no whitespaces
	sls_prd_key, -- all values match with other tables
	sls_cust_id, -- values match with other tables
	sls_order_dt, -- check for negative numbers or zeros, convert 0s to NULL. Change to date format from integer
	sls_ship_dt, --  check for negative numbers or zeros, convert 0s to NULL. Change to date format from integer
	sls_due_dt, --  check for negative numbers or zeros, convert 0s to NULL. Change to date format from integer
	sls_sales, -- check if sales have been calculated correctly
	sls_quantity, -- verify data accuracy and correct
	sls_price -- verify data accuracy and correct
FROM bronze.crm_sales_details

-- check for Invalid dates
SELECT
		NULLIF(sls_ship_dt,0) AS sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0
OR LENGTH(sls_ship_dt::TEXT) != 8
OR sls_ship_dt > 20500101
OR sls_ship_dt < 19000101

---check for invalid date orders
SELECT *
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt Or sls_order_dt > sls_due_dt

-- check for data consistency: between sales, quantity and price
-- sales = quantity * prce
-- Values must not be Null, 0 or negative

SELECT DISTINCT
	sls_sales AS old_sls_sales,
	sls_quantity,
	sls_price AS old_sls_price,

CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
	THEN sls_quantity * ABS(sls_price)
ELSE sls_sales
END AS sls_sales,

CASE WHEN sls_price IS NULL OR sls_price <=0 
	THEN sls_sales / NULLIF(sls_quantity,0)
ELSE sls_price
END AS sls_price
	
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY 1,2,3


----- final corrections----------------------------
SELECT
		sls_order_num,
		sls_prd_key,
		sls_cust_id,
		CASE WHEN sls_order_dt = 0 OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL
		ELSE CAST(CAST(sls_order_dt AS character varying)AS DATE)
		END AS sls_order_dt,
		CASE WHEN sls_ship_dt = 0 OR LENGTH(sls_ship_dt::TEXT) != 8 THEN NULL
		ELSE CAST(CAST(sls_ship_dt AS character varying)AS DATE)
		END AS sls_ship_dt,
		CASE WHEN sls_due_dt = 0 OR LENGTH(sls_due_dt::TEXT) != 8 THEN NULL
		ELSE CAST(CAST(sls_due_dt AS character varying)AS DATE)
		END AS sls_due_dt,
		
		CASE WHEN sls_sales IS NULL OR sls_sales <=0 OR sls_sales != sls_quantity * ABS(sls_price)
		THEN sls_quantity * ABS(sls_price)
		ELSE sls_sales
		END AS sls_sales,

		CASE WHEN sls_price IS NULL OR sls_price <=0 
		THEN sls_sales / NULLIF(sls_quantity,0)
		ELSE sls_price
		END AS sls_price,
		sls_quantity
FROM bronze.crm_sales_details


-------------erp_cust_AZ12--------------------------
SELECT 
	CASE WHEN cid LIKE 'NAS%'
	THEN SUBSTRING(cid, 4, LENGTH(cid))
	ELSE cid
	END AS cid,
	CASE WHEN bdate > NOW()
	THEN NULL
	ELSE bdate
	END AS bdate,
	CASE WHEN UPPER (TRIM(gen)) IN ('F', 'FEMALE') THEN  'Female'
		 WHEN UPPER (TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
	ELSE 'n/a'
	END AS gen
FROM bronze.erp_cust_az12
--------------erp_loc_a101------------
SELECT 
	REPLACE(cid, '-', '') cid,
	CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
		 WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
		 WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE cntry
	END AS cntry
FROM bronze.erp_loc_a101

------------------erp_px_cat_g1v2---------------
SELECT 
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2
