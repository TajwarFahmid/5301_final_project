/*=============================================================================
  SCRIPT 4: Q1 FEATURE ENGINEERING, ASSUMPTION TESTING & ANALYSES
  COURSE:   ASDS 5301 - Statistical Theory and Applications (Fall 2026)
  METHODS:  Paired t-Test (Parametric) + Wilcoxon Signed-Rank (Nonparametric)
=============================================================================*/

LIBNAME proj '/home/u63988430';

OPTIONS NODATE NONUMBER;
ODS GRAPHICS ON / WIDTH=7IN HEIGHT=4.5IN;

/*-----------------------------------------------------------------------------
  STEP 1: FEATURE ENGINEERING ON PAIRED PROCEDURES (N = 1,209)
-----------------------------------------------------------------------------*/
/* Compute tertile cutoffs for total Texas service volume */
PROC UNIVARIATE DATA=proj.analytic_wide NOPRINT;
    VAR services_F;
    OUTPUT OUT=work.vol_cuts PCTLPTS=33.3 66.7 PCTLPRE=p_;
RUN;

DATA proj.analytic_q1;
    IF _N_ = 1 THEN SET work.vol_cuts;
    SET proj.analytic_wide;
    LENGTH volume_tier $12 differential_dir $18;

    /* Feature 1: Total paired volume & utilization tier */
    total_paired_srvcs = services_F + services_O;
    IF services_F <= p_33_3 THEN volume_tier = '1: Low Vol';
    ELSE IF services_F <= p_66_7 THEN volume_tier = '2: Med Vol';
    ELSE volume_tier = '3: High Vol';

    /* Feature 2: Relative percentage payment change (Facility vs Office) */
    pct_pymt_diff = ((pymt_F - pymt_O) / pymt_O) * 100;

    /* Feature 3: Direction indicator */
    IF diff_pymt_raw < 0 THEN differential_dir = 'Facility < Office';
    ELSE IF diff_pymt_raw > 0 THEN differential_dir = 'Facility > Office';
    ELSE differential_dir = 'Equal';

    /* Feature 4: Absolute dollar & log gap magnitudes */
    abs_diff_raw = ABS(diff_pymt_raw);
    abs_diff_log = ABS(diff_pymt_log);

    DROP p_33_3 p_66_7;
RUN;

TITLE1 "Q1 Feature Summary: Engineered Payment & Volume Features (N = 1,209)";
PROC MEANS DATA=proj.analytic_q1 N MEAN STD MEDIAN Q1 Q3 MIN MAX MAXDEC=2;
    VAR diff_pymt_raw diff_pymt_log pct_pymt_diff total_paired_srvcs;
RUN;

/*-----------------------------------------------------------------------------
  STEP 2: ASSUMPTION DIAGNOSTICS (NORMALITY, SKEWNESS & SYMMETRY)
-----------------------------------------------------------------------------*/
TITLE1 "Q1 Assumption Check: Moments, Normality Tests & Wilcoxon Signed-Rank";
PROC UNIVARIATE DATA=proj.analytic_q1 NORMAL;
    VAR diff_pymt_raw diff_pymt_log pct_pymt_diff;
    HISTOGRAM diff_pymt_raw diff_pymt_log / NORMAL KERNEL;
    QQPLOT diff_pymt_raw diff_pymt_log / NORMAL(MU=EST SIGMA=EST);
    ODS SELECT Moments TestsForNormality LocationCounts Quantiles Histogram QQPlot;
RUN;

/*-----------------------------------------------------------------------------
  STEP 3: "MEATY" TOPIC 1A - PARAMETRIC PAIRED T-TEST (RAW & LOG SCALES)
-----------------------------------------------------------------------------*/
TITLE1 "Q1 Meaty Analysis (Parametric): Paired t-Test on Raw Medicare Payment ($)";
PROC TTEST DATA=proj.analytic_q1 ALPHA=0.05;
    PAIRED pymt_F * pymt_O;
    ODS OUTPUT Statistics=work.q1_raw_stats TTests=work.q1_raw_ttest;
RUN;

TITLE1 "Q1 Meaty Analysis (Parametric): Paired t-Test on Log Medicare Payment";
PROC TTEST DATA=proj.analytic_q1 ALPHA=0.05;
    PAIRED log_pymt_F * log_pymt_O;
    ODS OUTPUT Statistics=work.q1_log_stats TTests=work.q1_log_ttest;
RUN;

/*-----------------------------------------------------------------------------
  STEP 4: EFFECT SIZE (COHEN'S dz) & GEOMETRIC MEAN % DIFFERENTIAL
-----------------------------------------------------------------------------*/
DATA work.q1_effect_table;
    MERGE work.q1_raw_stats (RENAME=(Mean=Mean_Raw StdDev=SD_Raw LowerCLMean=LCL_Raw UpperCLMean=UCL_Raw))
          work.q1_log_stats (RENAME=(Mean=Mean_Log StdDev=SD_Log LowerCLMean=LCL_Log UpperCLMean=UCL_Log));
    
    Cohens_dz_Raw = Mean_Raw / SD_Raw;
    Cohens_dz_Log = Mean_Log / SD_Log;
    
    /* Back-transform log mean difference to exact Geometric Mean % Change */
    Geom_Mean_Ratio = EXP(Mean_Log);
    Geom_Pct_Diff   = (EXP(Mean_Log) - 1) * 100;
    Geom_Pct_LCL    = (EXP(LCL_Log) - 1) * 100;
    Geom_Pct_UCL    = (EXP(UCL_Log) - 1) * 100;

    KEEP Mean_Raw SD_Raw LCL_Raw UCL_Raw Cohens_dz_Raw
         Mean_Log SD_Log LCL_Log UCL_Log Cohens_dz_Log
         Geom_Mean_Ratio Geom_Pct_Diff Geom_Pct_LCL Geom_Pct_UCL;
RUN;

TITLE1 "Q1 Effect Sizes (Cohen's dz) & Back-Transformed Geometric Mean % Differential";
PROC PRINT DATA=work.q1_effect_table NOOBS;
    FORMAT Mean_Raw SD_Raw LCL_Raw UCL_Raw DOLLAR10.2
           Mean_Log SD_Log LCL_Log UCL_Log Cohens_dz_Raw Cohens_dz_Log Geom_Mean_Ratio 6.4
           Geom_Pct_Diff Geom_Pct_LCL Geom_Pct_UCL 6.2;
RUN;

/*-----------------------------------------------------------------------------
  STEP 5: ROBUSTNESS CHECK ACROSS UTILIZATION TIERS & SERVICE CATEGORIES
-----------------------------------------------------------------------------*/
TITLE1 "Q1 Sensitivity Check: Log Payment Differential by Volume Tier";
PROC MEANS DATA=proj.analytic_q1 N MEAN STD MEDIAN PVALUE T PROBT MAXDEC=3;
    CLASS volume_tier;
    VAR diff_pymt_log pct_pymt_diff;
RUN;

TITLE;
ODS GRAPHICS OFF;
