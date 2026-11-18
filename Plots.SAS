/*=============================================================================
  SCRIPT 3: PUBLICATION-READY FIGURES FOR REPORT & SLIDES (300 DPI)
  COURSE:   ASDS 5301 - Statistical Theory and Applications (Fall 2026)
  TEAM:     Tajwar Fahmid, Shreya Silwal, Sejal Dulal
=============================================================================*/

LIBNAME proj '/home/u63988430';

OPTIONS NODATE NONUMBER;
ODS GRAPHICS ON / RESET=ALL IMAGEFMT=PNG WIDTH=7.5IN HEIGHT=4.8IN ANTIALIASMAX=5000;

/*-----------------------------------------------------------------------------
  FIGURE 1 (EDA): Service Category Composition Across 1,209 Paired Codes
-----------------------------------------------------------------------------*/
TITLE1 "Figure 1: Distribution of Paired Texas HCPCS Procedures by Service Category (N = 1,209)";
PROC SGPLOT DATA=proj.analytic_wide;
    HBAR service_cat / CATEGORYORDER=RESPASC DATALABEL DATASKIN=NONE
                       FILLATTRS=(COLOR=CX2B5C8F);
    XAXIS LABEL="Number of Paired HCPCS Procedure Codes" GRID;
    YAXIS LABEL="CPT / HCPCS Service Category";
RUN;

/*-----------------------------------------------------------------------------
  FIGURE 2 (Q1): Paired Payment Scatterplot (Facility vs. Office, Log10 Scale)
  Shows how 79.2% of procedures fall below the 45-degree parity line
-----------------------------------------------------------------------------*/
DATA work.plot_q1_scatter;
    SET proj.analytic_wide;
    LENGTH Direction $28;
    IF diff_pymt_raw < 0 THEN Direction = "Facility < Office (79.2%)";
    ELSE Direction = "Facility >= Office (20.8%)";
RUN;

TITLE1 "Figure 2: Facility vs. Office Weighted Medicare Payment (1,209 Paired Procedures)";
TITLE2 "Dashed Line Indicates Equal Payment (Parity); Points Below Indicate Lower Facility Pay";
PROC SGPLOT DATA=work.plot_q1_scatter;
    SCATTER X=pymt_O Y=pymt_F / GROUP=Direction 
            MARKERATTRS=(SYMBOL=CIRCLEFILLED SIZE=5) TRANSPARENCY=0.35;
    LINEPARM X=1 Y=1 SLOPE=1 / LINEATTRS=(PATTERN=DASH COLOR=BLACK THICKNESS=1.5);
    XAXIS TYPE=LOG LOGBASE=10 LABEL="Office Weighted Medicare Payment ($, Log Scale)" GRID;
    YAXIS TYPE=LOG LOGBASE=10 LABEL="Facility Weighted Medicare Payment ($, Log Scale)" GRID;
    KEYLEGEND / TITLE="Site-of-Service Differential" LOCATION=INSIDE POSITION=TOPLEFT;
RUN;

/*-----------------------------------------------------------------------------
  FIGURE 3 (Q1 Normality Diagnostic): Distribution of Log Paired Differences
  Supports Paired t-Test + Wilcoxon Signed-Rank Test
-----------------------------------------------------------------------------*/
TITLE1 "Figure 3: Distribution of Log Paired Payment Differences [log(Facility) - log(Office)]";
TITLE2 "Vertical Reference Line at 0 (No Payment Difference)";
PROC SGPLOT DATA=proj.analytic_wide;
    HISTOGRAM diff_pymt_log / BINWIDTH=0.12 FILLATTRS=(COLOR=CX4C72B0) TRANSPARENCY=0.25;
    DENSITY diff_pymt_log / TYPE=NORMAL LINEATTRS=(COLOR=CXC44E52 THICKNESS=2 PATTERN=DASH);
    DENSITY diff_pymt_log / TYPE=KERNEL LINEATTRS=(COLOR=CX1F4E78 THICKNESS=2);
    REFLINE 0 / AXIS=X LINEATTRS=(COLOR=BLACK THICKNESS=1.5 PATTERN=DOT) LABEL="Zero Diff";
    XAXIS LABEL="Log Paired Payment Difference (Facility - Office)" GRID;
    YAXIS LABEL="Percent of Procedures";
    KEYLEGEND / LOCATION=INSIDE POSITION=TOPRIGHT;
RUN;

/*-----------------------------------------------------------------------------
  FIGURE 4 (Q2): Clustered Boxplot of Log Charge Markup by Setting & Category
-----------------------------------------------------------------------------*/
TITLE1 "Figure 4: Charge Markup Ratio (Log Scale) by Service Category and Site of Service";
PROC SGPLOT DATA=proj.analytic_long;
    VBOX log_markup / CATEGORY=service_cat GROUP=setting_label GROUPDISPLAY=CLUSTER
                      BOXWIDTH=0.7 MEANATTRS=(SYMBOL=DIAMOND COLOR=BLACK);
    XAXIS LABEL="CPT / HCPCS Service Category";
    YAXIS LABEL="Log Charge Markup [log(Submitted Charge / Allowed Amount)]" GRID;
    KEYLEGEND / TITLE="Site of Service" LOCATION=OUTSIDE POSITION=BOTTOM;
RUN;

/*-----------------------------------------------------------------------------
  FIGURE 5 (Q2 Interaction): Mean Log Markup Profile Plot (Setting x Category)
  Directly visualizes the Two-Way ANOVA interaction effect
-----------------------------------------------------------------------------*/
PROC MEANS DATA=proj.analytic_long NOPRINT NWAY;
    CLASS service_cat setting_label;
    VAR log_markup;
    OUTPUT OUT=work.q2_profile MEAN=mean_log_markup LCLM=lcl UCLM=ucl;
RUN;

TITLE1 "Figure 5: Interaction Profile of Mean Log Charge Markup with 95% Confidence Intervals";
PROC SGPLOT DATA=work.q2_profile;
    SERIES X=service_cat Y=mean_log_markup / GROUP=setting_label 
           MARKERS MARKERATTRS=(SYMBOL=CIRCLEFILLED SIZE=8) LINEATTRS=(THICKNESS=2.5);
    SCATTER X=service_cat Y=mean_log_markup / GROUP=setting_label 
            YERRORLOWER=lcl YERRORUPPER=ucl MARKERATTRS=(SIZE=0);
    XAXIS LABEL="CPT / HCPCS Service Category";
    YAXIS LABEL="Mean Log Charge Markup (95% CI)" GRID;
    KEYLEGEND / TITLE="Site of Service" LOCATION=INSIDE POSITION=TOPLEFT;
RUN;

/*-----------------------------------------------------------------------------
  FIGURE 6 (Q3): Proportion of High-Markup Procedures (> Overall Median) by Setting
-----------------------------------------------------------------------------*/
PROC UNIVARIATE DATA=proj.analytic_long NOPRINT;
    VAR markup;
    OUTPUT OUT=work.med_out MEDIAN=global_med;
RUN;

DATA work.plot_q3_bar;
    IF _N_ = 1 THEN SET work.med_out;
    SET proj.analytic_long;
    LENGTH Markup_Tier $26;
    IF markup > global_med THEN Markup_Tier = "High Markup (> Median)";
    ELSE Markup_Tier = "Normal Markup (<= Median)";
RUN;

TITLE1 "Figure 6: Share of Procedures Exceeding Overall Median Markup by Site of Service";
PROC SGPLOT DATA=work.plot_q3_bar;
    VBAR setting_label / GROUP=Markup_Tier GROUPDISPLAY=STACK STAT=PERCENT 
                         SEGLABEL SEGLABELATTRS=(WEIGHT=BOLD COLOR=WHITE);
    XAXIS LABEL="Site of Service (n = 1,209 Paired Codes Each)";
    YAXIS LABEL="Percentage of Procedures (%)" GRID;
    KEYLEGEND / TITLE="Charge Markup Tier" LOCATION=OUTSIDE POSITION=BOTTOM;
RUN;

TITLE;
ODS GRAPHICS OFF;
