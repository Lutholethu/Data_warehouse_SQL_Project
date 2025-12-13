/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Script Purpose:
    This script creates tables in the 'bronze' schema, dropping existing tables 
    if they already exist.
	  Run this script to re-define the DDL structure of 'bronze' Tables
===============================================================================
*/

CREATE TABLE IF NOT EXISTS bronze.crm_cust_info
(
	cst_id integer,
	cst_key character varying (50),
	cst_firstname character varying (50),
	cst_lastname character varying (50),
	cst_marital_status character varying (50),
	cst_gndr character varying (50),
	cst_create_date character varying (50)
	
);

CREATE TABLE IF NOT EXISTS bronze.crm_prd_info
(
    prd_id integer,
	prd_key character varying (50),
	prd_nm character varying (50),
	prd_cost integer,
	prd_line character varying (50),
	prd_start_dt date,
	prd_end_dt date
);

CREATE TABLE IF NOT EXISTS bronze.crm_sales_details
(
	sls_order_num character varying (50),
	sls_prd_key character varying (50),
	sls_cust_id integer,
	sls_order_dt integer,
	sls_ship_dt integer,
	sls_due_dt integer, 
	sls_sales integer,
	sls_quantity integer,
	sls_price integer
);

CREATE TABLE IF NOT EXISTS bronze.erp_cust_AZ12
(
	CID character varying (50),
	BDATE date,
	GEN character varying (50)
);

CREATE TABLE IF NOT EXISTS bronze.erp_LOC_A101
(
	CID character varying (50),
	CNTRY character varying (50)

);

CREATE TABLE IF NOT EXISTS bronze.erp_PX_CAT_G1V2
(
	ID character varying (50),
	CAT character varying (50),
	SUBCAT character varying (50),
	maintenance character varying (50)
);
