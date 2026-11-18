/*=============================================================================
  SCRIPT 2: EXPLORATORY DATA ANALYSIS (EDA) & PAIRED PREPROCESSING
  COURSE:   ASDS 5301 - Statistical Theory and Applications (Fall 2026)
  TEAM:     Tajwar Fahmid, Shreya Silwal, Sejal Dulal
=============================================================================*/

/* Connect to permanent library where Script 1 saved cms_tx_clean */
LIBNAME proj '/home/u63988430';

OPTIONS NODATE NONUMBER;
ODS GRAPHICS ON / WIDTH=7IN HEIGHT=4.5IN;

/*-----------------------------------------------------------------------------
  STEP 1: RAW PROVIDER-LEVEL EDA & DATA QUALITY AUDIT (N = 686,647)
-----------------------------------------------------------------------------*/
TITLE1 "EDA 1A: Raw Texas Provider-Service Summary Statistics";
PROC MEANS DATA=proj.cms_tx_clean N NMISS MEAN STD MEDIAN Q1 Q3 MIN MAX MAXDEC=2;
    VAR total_benes total_services submitted_charge allowed_amount medicare_payment std_payment;
RUN;

TITLE1 "EDA 1B: Raw Texas Frequencies by Setting, Drug Status & Entity Type";
PROC FREQ DATA=proj.cms_tx_clean;
    TABLES setting is_drug entity_type / MISSING;
RUN;

/* Filter to valid positive financial/service records in Facility (F) or Office (O) */
DATA work.cms_tx_valid;
    SET proj.cms_tx_clean;
    WHERE setting IN ('F', 'O')
      AND NOT MISSING(hcpcs_code)
      AND total_services > 0
      AND submitted_charge > 0
      AND allowed_amount > 0
      AND medicare_payment > 0;
RUN;

/*-----------------------------------------------------------------------------
  STEP 2: TOTAL_SERVICES-WEIGHTED AGGREGATION & HCPCS PAIRING
-----------------------------------------------------------------------------*/
/* Step 2A: Compute total_services-weighted means per (hcpcs_code, setting) */
PROC SQL;
    CREATE TABLE work.code_setting_agg AS
    SELECT 
        hcpcs_code,
        MAX(hcpcs_desc) AS hcpcs_desc,
        MAX(is_drug) AS is_drug,
        setting,
        COUNT(*) AS n_providers,
        SUM(total_benes) AS sum_benes,
        SUM(total_services) AS sum_services,
        SUM(submitted_charge * total_services) / SUM(total_services) AS w_submitted_charge,
        SUM(allowed_amount * total_services)   / SUM(total_services) AS w_allowed_amount,
        SUM(medicare_payment * total_services) / SUM(total_services) AS w_medicare_payment
    FROM work.cms_tx_valid
    GROUP BY hcpcs_code, setting;
QUIT;

/* Step 2B: Identify HCPCS codes billed in BOTH Facility (F) and Office (O) */
PROC SQL;
    CREATE TABLE work.paired_codes AS
    SELECT hcpcs_code
    FROM work.code_setting_agg
    GROUP BY hcpcs_code
    HAVING COUNT(DISTINCT setting) = 2;
QUIT;

/* Step 2C: Build Long Analytic Table (1,209 codes x 2 settings = 2,418 rows) */
PROC SQL;
    CREATE TABLE work.analytic_long AS
    SELECT a.*
    FROM work.code_setting_agg AS a
    INNER JOIN work.paired_codes AS p
        ON a.hcpcs_code = p.hcpcs_code
    ORDER BY a.hcpcs_code, a.setting;
QUIT;

/* Feature Engineering: CPT/HCPCS Service Category, Markup & Log Outcomes */
DATA proj.analytic_long;
    SET work.analytic_long;
    LENGTH service_cat $15 setting_label $10;
    
    setting_label = IFC(setting = 'F', 'Facility', 'Office');
    
    /* Derive CPT/HCPCS Service Category from standard code ranges */
    num_code = INPUT(SUBSTR(STRIP(hcpcs_code), 1, 5), ?? 8.);
    IF NOT MISSING(num_code) THEN DO;
        IF 10021 <= num_code <= 69990 THEN service_cat = 'Surgery';
        ELSE IF 70010 <= num_code <= 79999 THEN service_cat = 'Radiology';
        ELSE IF 80047 <= num_code <= 89398 THEN service_cat = 'Pathology/Lab';
        ELSE IF 90281 <= num_code <= 99607 THEN service_cat = 'Medicine';
        ELSE service_cat = 'Other';
    END;
    ELSE service_cat = 'Other';

    /* Charge Markup = Submitted Charge / Medicare Allowed Amount */
    markup      = w_submitted_charge / w_allowed_amount;
    log_markup  = LOG(markup);
    log_payment = LOG(w_medicare_payment);
    
    DROP num_code;
RUN;

/* Step 2D: Build Wide Paired Table (1 row per HCPCS code = 1,209 rows) for Q1 */
PROC SQL;
    CREATE TABLE proj.analytic_wide AS
    SELECT 
        f.hcpcs_code,
        f.hcpcs_desc,
        f.service_cat,
        f.is_drug,
        f.n_providers AS providers_F,
        o.n_providers AS providers_O,
        f.sum_services AS services_F,
        o.sum_services AS services_O,
        f.w_medicare_payment AS pymt_F,
        o.w_medicare_payment AS pymt_O,
        (f.w_medicare_payment - o.w_medicare_payment) AS diff_pymt_raw,
        f.log_payment AS log_pymt_F,
        o.log_payment AS log_pymt_O,
        (f.log_payment - o.log_payment) AS diff_pymt_log,
        f.markup AS markup_F,
        o.markup AS markup_O,
        f.log_markup AS log_markup_F,
        o.log_markup AS log_markup_O
    FROM proj.analytic_long (WHERE=(setting='F')) AS f
    INNER JOIN proj.analytic_long (WHERE=(setting='O')) AS o
        ON f.hcpcs_code = o.hcpcs_code
    ORDER BY f.hcpcs_code;
QUIT;

/*-----------------------------------------------------------------------------
  STEP 3: PAIRED ANALYTIC DATASET EDA & PROPOSAL VERIFICATION
-----------------------------------------------------------------------------*/
TITLE1 "EDA 2A: Service Category & Drug Breakdown Across 1,209 Paired Codes";
PROC FREQ DATA=proj.analytic_wide;
    TABLES service_cat is_drug / NOCUM;
RUN;

TITLE1 "EDA 2B: Weighted Payment & Markup Summary by Setting (N = 2,418 Pairs)";
PROC MEANS DATA=proj.analytic_long N MEAN STD MEDIAN Q1 Q3 MIN MAX MAXDEC=2;
    CLASS setting_label;
    VAR w_submitted_charge w_allowed_amount w_medicare_payment markup log_markup log_payment;
RUN;

/* Verify Proposal Pilot Check: Facility payment < Office payment in 958/1,209 codes */
DATA work.pilot_verification;
    SET proj.analytic_wide;
    facility_lower = (diff_pymt_raw < 0);
RUN;

TITLE1 "EDA 2C: Pilot Verification (Proportion of Codes Where Facility Pay < Office Pay)";
PROC FREQ DATA=work.pilot_verification;
    TABLES facility_lower;
RUN;

/* Top 10 highest-volume paired procedures in Texas for presentation context */
PROC SORT DATA=proj.analytic_wide OUT=work.top_procs;
    BY DESCENDING services_O;
RUN;

TITLE1 "EDA 2D: Top 10 Highest-Volume Paired Procedures in Texas (by Office Services)";
PROC PRINT DATA=work.top_procs (OBS=10) NOOBS;
    VAR hcpcs_code service_cat pymt_F pymt_O diff_pymt_raw markup_F markup_O;
    FORMAT pymt_F pymt
