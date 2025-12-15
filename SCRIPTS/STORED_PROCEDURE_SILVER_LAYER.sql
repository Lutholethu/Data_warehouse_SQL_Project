/* 
=========================================================================================
STORED PROCEDURE: LOAD SILVER LAYER. SOURCE -> BRONZE LAYER
=========================================================================================
Script purpose:
	This stored procedure loads data into the 'SILVER layer 'schema from bronze layer cleaned and standardized files.
	The procedure :
	1. Truncates the bronze tables before loading data.
	2. Uses the INSERT INTO command to load data that has been cleaned from the bronze layer files to the silver tables.

Parameters:
	NONE
	This stored procedure does not accept any parameters or return any values

Excecution:
- Also measures the run time for the procedure

DO $$
DECLARE
    t_start timestamptz := clock_timestamp();
    t_end   timestamptz;
BEGIN
    CALL silver.load_silver();

    t_end := clock_timestamp();
    RAISE NOTICE 'Procedure ran in % ms', EXTRACT(MILLISECOND FROM t_end - t_start);
END $$;

=========================================================================================
*/


CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
BEGIN

RAISE NOTICE '>> Truncating silver.crm_cust_info';
TRUNCATE TABLE silver.crm_cust_info;
RAISE NOTICE '>> Inserting clean and standardized data into silver.crm_cust_info';
INSERT INTO silver.crm_cust_info
(cst_id,
 cst_key,
 cst_firstname,
 cst_lastname,
 cst_marital_status,
 cst_gndr,
 cst_create_date
)

SELECT 
	cst_id,
	cst_key,
	TRIM(cst_firstname) AS cst_firstname, 
	TRIM(cst_lastname) AS cst_lastname, 

	CASE
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
		WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
		ELSE NULL
	END cst_marital_status,
	
	CASE 		
		WHEN UPPER(TRIM (cst_gndr)) = 'F' THEN  'Female'
		WHEN UPPER(TRIM (cst_gndr)) = 'M' THEN  'Male'
		ELSE NULL
	END cst_gndr,
	cst_create_date
FROM (
		SELECT *,
		RANK() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC)
		AS flag_last
		FROM bronze.crm_cust_info
		WHERE cst_id IS NOT NULL
)
WHERE flag_last = 1 ;

RAISE NOTICE '>> Truncating silver.crm_prd_info';
TRUNCATE silver.crm_prd_info;
RAISE NOTICE'>> Inserting clean and standardized data into silver.crm_prd_info';
INSERT INTO silver.crm_prd_info
(
	prd_id,
	cat_id,
	prd_key,
	prd_nm,
	prd_cost,
	prd_line,
	prd_start_dt,
	prd_end_dt
)
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
FROM bronze.crm_prd_info;

RAISE NOTICE'>> Truncating silver.crm_sales_details';
TRUNCATE silver.crm_sales_details;
RAISE NOTICE '>> Inserting clean and standardized data into silver.crm_sales_details';
INSERT INTO silver.crm_sales_details
(
	sls_order_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price

)
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
FROM bronze.crm_sales_details;

RAISE NOTICE '>> Truncating silver.erp_cust_az12';
TRUNCATE silver.erp_cust_az12;
RAISE NOTICE '>> Inserting clean and standardized data into silver.erp_cust_az12 ';
INSERT INTO silver.erp_cust_az12
(
	cid,
	bdate,
	gen
)
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
FROM bronze.erp_cust_az12;


RAISE NOTICE '>> Truncating silver.erp_loc_a101 ';
TRUNCATE silver.erp_loc_a101;
RAISE NOTICE '>> Inserting clean and standardized data into silver.erp_loc_a101 ';
INSERT INTO silver.erp_loc_a101
(
	cid,
	cntry
)
SELECT 
	REPLACE(cid, '-', '') cid,
	CASE WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
		 WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
		 WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
		 ELSE cntry
	END AS cntry
FROM bronze.erp_loc_a101;


RAISE NOTICE '>> Truncating silver.erp_px_cat_g1v2';
TRUNCATE silver.erp_px_cat_g1v2;
RAISE NOTICE '>> Inserting clean and standardized data into silver.erp_px_cat_g1v2 ';
INSERT INTO silver.erp_px_cat_g1v2
(
	id,
	cat,
	subcat,
	maintenance
)
SELECT 
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2;

EXCEPTION 
	WHEN SQLSTATE '42501' THEN 
	RAISE NOTICE 'ERROR: A FILE COULD NOT BE OPENED';

END;
$$;