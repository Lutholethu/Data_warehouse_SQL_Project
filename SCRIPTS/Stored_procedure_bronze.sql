/* 
=========================================================================================
STORED PROCEDURE: LOAD BRONZE LAYER. SOURCE -> BRONZE LAYER
=========================================================================================
Script purpose:
	This stored procedure loads data into the 'bronze layer 'schema from CSV files.
	The procedure :
	1. Truncates the bronze tables before loading data.
	2. Uses the COPY command to load data from the CSV files to the bronze tables.

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
    CALL bronze.load_bronze();

    t_end := clock_timestamp();
    RAISE NOTICE 'Procedure ran in % ms', EXTRACT(MILLISECOND FROM t_end - t_start);
END $$;

=========================================================================================
*/


CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS $$
BEGIN


	RAISE NOTICE '===========================';
	RAISE NOTICE 'Loading data into the bronze layer';

	RAISE NOTICE '>>Truncating data into bronze.crm_cust_info';

	TRUNCATE TABLE bronze.crm_cust_info;

	RAISE NOTICE '>> Loading data into bronze.crm_cust_info';
	
	COPY bronze.crm_cust_info 
	FROM '/Users/elethu/Desktop/data ware_house project/crm/cust_info.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	); 

	RAISE NOTICE '===============================';
	RAISE NOTICE '>>Truncating table: bronze.crm_prd_info';
	
	TRUNCATE TABLE bronze.crm_prd_info;
	COPY bronze.crm_prd_info
	FROM '/Users/elethu/Desktop/data ware_house project/crm/prd_info.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	);

	
	RAISE NOTICE '===============================';
	RAISE NOTICE '>>Truncating table: bronze.crm_sales_details';
	
	TRUNCATE TABLE bronze.bronze.crm_sales_details;
	COPY bronze.crm_sales_details
	FROM '/Users/elethu/Desktop/data ware_house project/crm/sales_details.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	);

	RAISE NOTICE '===============================';
	RAISE NOTICE '>>Truncating table: bronze.erp_cust_az12';
	
	TRUNCATE TABLE bronze."bronze.erp_cust_az12";
	COPY bronze.erp_cust_az12
	FROM '/Users/elethu/Desktop/data ware_house project/erp/CUST_AZ12.csv.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	);

	RAISE NOTICE '===============================';
	RAISE NOTICE '>>Truncating table: bronze.erp_loc_a101';
	
	TRUNCATE TABLE bronze."bronze.erp_loc_a101";
	COPY bronze.erp_loc_101
	FROM '/Users/elethu/Desktop/data ware_house project/erp/LOC_A101.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	);

	RAISE NOTICE '===============================';
	RAISE NOTICE '>>Truncating table: bronze.erp_px_cat_g1v2';
	
	TRUNCATE TABLE bronze."bronze.erp_px_cat_g1v2";
	COPY bronze.erp_px_cat_g1v2
	FROM '/Users/elethu/Desktop/data ware_house project/erp_PX_CAT_G1V2.csv'
	WITH (FORMAT CSV, DELIMITER ';', HEADER
	);

	
EXCEPTION 
	WHEN SQLSTATE '42501' THEN 
	RAISE NOTICE 'ERROR: A FILE COULD NOT BE OPENED';

END;
$$;