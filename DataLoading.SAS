/* Paste the exact Location from right-click -> Properties here: */
%LET zip_path = /home/u63988430/Medicare_Physician_Other_Practitioners_by_Provider_and_Service_2024.zip;

FILENAME checkzip ZIP "&zip_path";

DATA _NULL_;
    did = DOPEN("checkzip");
    IF did > 0 THEN DO;
        PUT "=== ZIP OPENED SUCCESSFULLY ===";
        DO i = 1 TO DNUM(did);
            fname = DREAD(did, i);
            PUT "Exact MEMBER name inside ZIP: " fname;
        END;
        rc = DCLOSE(did);
    END;
    ELSE PUT "ERROR: Could not open ZIP. Check the Location path in Properties.";
RUN;

FILENAME checkzip CLEAR;

/*=============================================================================
  STEP 1: DIRECT SEQUENTIAL READ FROM ZIP ARCHIVE WITH CLEAN COLUMN NAMES
=============================================================================*/
%LET zip_path       = /home/u63988430/Medicare_Physician_Other_Practitioners_by_Provider_and_Service_2024.zip;
%LET csv_inside_zip = Medicare_Physician_Other_Practitioners_by_Provider_and_Service_2024.csv;

FILENAME inzip ZIP "&zip_path" MEMBER="&csv_inside_zip";

DATA work.cms_tx_clean;
    INFILE inzip DSD DLM=',' TRUNCOVER FIRSTOBS=2 LRECL=32767;

    LENGTH
        npi                $12
        last_org_name      $70
        first_name         $30
        middle_init        $5
        credentials        $25
        entity_type        $3
        street_1           $60
        street_2           $60
        city               $40
        state              $5
        state_fips         $5
        zip5               $10
        ruca_code          $5
        ruca_desc          $80
        country            $5
        specialty          $70
        mdcr_participating $3
        hcpcs_code         $10
        hcpcs_desc         $256
        is_drug            $3
        setting            $3
    ;

    INPUT
        npi                :$12.
        last_org_name      :$70.
        first_name         :$30.
        middle_init        :$5.
        credentials        :$25.
        entity_type        :$3.
        street_1           :$60.
        street_2           :$60.
        city               :$40.
        state              :$5.
        state_fips         :$5.
        zip5               :$10.
        ruca_code          :$5.
        ruca_desc          :$80.
        country            :$5.
        specialty          :$70.
        mdcr_participating :$3.
        hcpcs_code         :$10.
        hcpcs_desc         :$256.
        is_drug            :$3.
        setting            :$3.
        total_benes
        total_services
        bene_day_services
        submitted_charge
        allowed_amount
        medicare_payment
        std_payment
    ;
RUN;

FILENAME inzip CLEAR;

/*=============================================================================
  STEP 2: INSPECT COLUMN STRUCTURE, FIRST 10 ROWS & SUMMARY STATS
=============================================================================*/
TITLE "1. Renamed Column Structure (All 28 Columns)";
PROC CONTENTS DATA=work.cms_tx_clean VARNUM;
RUN;

TITLE "2. First 10 Rows of Cleaned Texas CMS Dataset";
PROC PRINT DATA=work.cms_tx_clean (OBS=10);
    VAR npi last_org_name specialty hcpcs_code hcpcs_desc is_drug setting 
        total_benes total_services submitted_charge allowed_amount medicare_payment;
RUN;

TITLE "3. Summary Statistics for Key Financial & Utilization Variables";
PROC MEANS DATA=work.cms_tx_clean N NMISS MEAN STD MIN MEDIAN MAX MAXDEC=2;
    VAR total_benes total_services submitted_charge allowed_amount medicare_payment std_payment;
RUN;

TITLE "4. Frequency Check: Setting (F vs. O) & Drug Indicator";
PROC FREQ DATA=work.cms_tx_clean;
    TABLES setting is_drug / MISSING;
RUN;
TITLE;
