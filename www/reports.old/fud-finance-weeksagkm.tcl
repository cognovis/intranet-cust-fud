# /packages/intranet-reporting/www/finance-trans-pm-productivity.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/ for licensing details.


ad_page_contract {
	testing reports	
    @param start_year Year to start the report
    @param start_unit Month or week to start within the start_year
} {
    { timerangeset "WEEK" } 
    { timerangeopt "week" }
    { start_date "" }
    { end_date "" }
    { level_of_detail 1 }
    { output_format "html" }
    project_id:integer,optional
    project_manager_id:integer,optional
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set menu_label "fud-finance-weeksagkm"

set current_user_id [ad_maybe_redirect_for_registration]

set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

if {![string equal "t" $read_p]} {
    ad_return_complaint 1 "<li>
[lang::message::lookup "" intranet-reporting.You_dont_have_permissions "You don't have the necessary permissions to view this page"]"
    return
}

# Check that Start & End-Date have correct format
if {"" != $start_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
}

if {"" != $end_date && ![regexp {^[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]$} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
}


# ------------------------------------------------------------
# Page Settings

set page_title "Zeit+Agent+KM"
set context_bar [im_context_bar $page_title]
set context ""

set help_text "
<strong>Zeit+Agent+KM</strong><br>

 
"


# ------------------------------------------------------------
# Defaults

set rowclass(0) "roweven"
set rowclass(1) "rowodd"

set days_in_past 0

set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set cur_format [im_l10n_sql_currency_format]
set date_format "YYYY-MM-DD"

db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month,
	to_char(sysdate::date - :days_in_past::integer, 'DD') as todays_day
from dual
"

if {"" == $start_date} { 
    set start_date "$todays_year-01-01"
}

if {"" == $end_date} { 
    set end_date '2099-12-31'
}

#if {"" == $timerangeopt} {
#     set timerangeopt 'week'
#}

# Maxlevel is 4. Normalize in order to show the right drop-down element
if {$level_of_detail > 3} { set level_of_detail 3 }


db_1row end_date "
select
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'YYYY') as end_year,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'MM') as end_month,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'DD') as end_day
from dual
"

db_1row todays_week "
select
	
	(SELECT EXTRACT (WEEK FROM sysdate::date)) AS todays_week
from dual
"


switch $timerangeopt {
	1 { set timerangeset "WEEK" }
	2 { set timerangeset "MONTH" }
	3 { set timerangeset "YEAR" }
}

set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting/finance-trans-pm-productivity.tcl" {start_date end_date} ]


# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {[info exists project_manager_id]} {
    lappend criteria "p.project_lead_id = :project_manager_id"
}

if {[info exists project_id]} {
    lappend criteria "p.project_id = :project_id"
}

# Select project & subprojects
if {[info exists project_id]} {
    lappend criteria "p.project_id in (
	select
		p.project_id
	from
		im_projects p,
		im_projects parent_p
	where
		parent_p.project_id = :project_id
		and p.tree_sortkey between parent_p.tree_sortkey and tree_right(parent_p.tree_sortkey)
    )"
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#


set inner_sql "
select
	c.cost_id,
	c.cost_type_id,
	c.cost_status_id,
	c.cost_nr,
	c.cost_name,
	c.effective_date,
	c.customer_id,
	c.provider_id,
	round((c.paid_amount * 
	  im_exchange_rate(c.effective_date::date, c.currency, :default_currency)) :: numeric
	  , 2) as paid_amount_converted,
	c.paid_amount,
	c.paid_currency,
	round((c.amount * 
	  im_exchange_rate(c.effective_date::date, c.currency, :default_currency)) :: numeric
	  , 2) as amount_converted,
	c.amount,
	c.currency,
	r.object_id_one as project_id
from
	im_costs c
	LEFT OUTER JOIN acs_rels r on (c.cost_id = r.object_id_two)
where
	c.cost_type_id in (3700, 3702)
	--and c.effective_date >= to_date(:start_date, 'YYYY-MM-DD')
	--and c.effective_date < to_date(:end_date, 'YYYY-MM-DD')
	--and c.effective_date::date < to_date(:end_date, 'YYYY-MM-DD')
	--and im_name_from_id(c.project_id) not like '1%'
	and c.cost_status_id  not in (11000197, 3812)
"


set sql "
select
	c.*,
	to_char(p.start_date, :date_format) as effective_date_formatted,
	to_char(p.start_date, 'YYMM')::integer * customer_id as effective_month,
	to_char(p.start_date, 'YYYY') as year,	
	to_char(p.start_date, 'Q') as quater,
	to_char(p.start_date, 'YYYY-Q') as year_quater,
	(SELECT EXTRACT (WEEK FROM p.start_date)) AS week,
	(SELECT EXTRACT (MONTH FROM p.start_date)) AS month,
	(SELECT EXTRACT ($timerangeset FROM p.start_date)) as timerange,
	--(SELECT EXTRACT (MONTH FROM p.start_date)) as timerange,
	CASE WHEN c.cost_type_id = 3700 THEN c.amount_converted END as invoice_amount,
	CASE WHEN (c.cost_type_id = 3702 and c.cost_name LIKE 'C%') THEN c.amount_converted END as quote_amount,
	CASE WHEN c.cost_type_id = 3700 THEN to_char(c.amount, :cur_format) || ' ' || c.currency 
	END as invoice_amount_pretty,
	CASE WHEN (c.cost_type_id = 3702 and c.cost_name LIKE 'C%') THEN to_char(c.amount, :cur_format) || ' ' || c.currency 
	END as quote_amount_pretty,
	to_char(c.paid_amount, :cur_format) || ' ' || c.paid_currency as paid_amount_pretty,
	p.project_name,
	im_name_from_id(p.interco_company_id) as agency,
	p.interco_company_id,
	CASE WHEN c.cost_name  LIKE 'C%' THEN '1' END as project_count,	
	CASE WHEN c.cost_name  LIKE 'Q%' THEN '1' END as quote_count,
	--CASE WHEN (substring(p.project_path,1,6) LIKE to_char(CURRENT_DATE,'YYMMDD')) THEN '1' END as quote_count,
  to_char(CURRENT_DATE,'YYMMDD'),
	--CASE WHEN (substring(p.project_path,1,6) LIKE to_char(CURRENT_DATE,'YYMMDD')) THEN '1' END as quote_count,
  to_char(CURRENT_DATE,'YYMMDD'),
	--CASE WHEN p.project_nr !='' THEN '1' END as project_count,
	p.project_nr,
	p.project_lead_id as project_manager_id,
	im_name_from_user_id(p.project_lead_id) as project_manager_name
from
	($inner_sql) c
	LEFT OUTER JOIN im_projects p on (c.project_id = p.project_id)

where
	1 = 1
	$where_clause
	--and p.project_lead_id is not null
	and parent_id is null
	and p.start_date >= :start_date
	and p.start_date <= :end_date
order by
	--(SELECT EXTRACT (WEEK FROM p.start_date)) DESC,	
	timerange DESC,	
	im_name_from_id(p.interco_company_id),
	im_name_from_user_id(p.project_lead_id),
	p.project_name DESC
"


set report_def [list \
    group_by timerange \
    header {
	<b>$year</b>
	<b>$timerangeset $timerange</b>
    } \
        content [list \
            group_by interco_company_id \
            header { } \
	    content [list \
	           group_by project_manager_name \
	            header { } \
		    content [list \
			    header {
				""
				""
				""
				""
				$project_name
				"<i>$invoice_amount_pretty $default_currency</i>" 
				"<i>$invoice_amount_pretty $default_currency</i>" 
				""
			    } \
			    content {} \
		    ] \
	            footer {
			""
			""
			""
			$project_manager_name
			""
			"<i>$invoice_pm_subtotal $default_currency</i>" 
			"<i>$quote_pm_subtotal $default_currency</i>" 
			"<i>$project_count_pm_subtotal</i>" 
			"<i>$quote_count_pm_subtotal</i>" 
	            } \
	    ] \
	footer {
		"" 
		"" 
		<b>$agency</b>
		"" 
		""
		"<i><b>$invoice_ag_subtotal $default_currency</b></i>" 
		"<i><b>$quote_ag_subtotal $default_currency</b></i>" 
		"<i><b>$project_count_ag_subtotal</b></i>" 
		"<i><b>$quote_count_ag_subtotal</b></i>" 
	} \
    ] \
    footer {  
		"" 
		""
		"" 
		"<b>Total $timerangeset $timerange</b>" 
		""
		"<nobr><b>$invoice_subtotal $default_currency</b></nobr>" 
		"<nobr><b>$quote_subtotal $default_currency</b></nobr>"
		"<nobr><b>$project_count_subtotal</b></nobr>"
		"<nobr><b>$quote_count_subtotal</b></nobr>"
		
    } \
]

set invoice_total 0
set quote_total 0
set project_count_total 0
set quote_count_total 0

# Global header/footer
set header0 {"Jahr" "Zeit" "Agentur" "KM" "____" "Rechnung" "Auftragsbestaetigung" "Auftragsanzahl" "KVA-Anzahl"}
set footer0 {
	""	
	"" 
	"" 
	""
	"<br><b>Total:</b>" 
	"<br><b>$invoice_total $default_currency</b>" 
	"<br><b>$quote_total $default_currency</b>" 
	"<br><b>$project_count_total</b>" 
	"<br><b>$quote_count_total</b>" 
	
}

#
# Subtotal Counters (per project)
#
set invoice_subtotal_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_subtotal \
        reset \$timerange \
        expr "\$invoice_amount+0" \
]

set quote_subtotal_counter [list \
        pretty_name "Quote Amount" \
        var quote_subtotal \
        reset \$timerange \
        expr "\$quote_amount+0" \
]

set project_count_subtotal_counter [list \
        pretty_name "Project Count" \
        var project_count_subtotal \
        reset \$timerange \
        expr "\$project_count+0" \
]

set quote_count_subtotal_counter [list \
        pretty_name "Project Count" \
        var quote_count_subtotal \
        reset \$timerange \
        expr "\$quote_count+0" \
]

#
# Subtotal Counters (per agency)
#
set invoice_ag_subtotal_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_ag_subtotal \
        reset \$interco_company_id \
        expr "\$invoice_amount+0" \
]

set quote_ag_subtotal_counter [list \
        pretty_name "Quote Amount" \
        var quote_ag_subtotal \
        reset \$interco_company_id \
        expr "\$quote_amount+0" \
]

set project_count_ag_subtotal_counter [list \
        pretty_name "Project Count" \
        var project_count_ag_subtotal \
        reset \$interco_company_id \
        expr "\$project_count+0" \
]

set quote_count_ag_subtotal_counter [list \
        pretty_name "Project Count" \
        var quote_count_ag_subtotal \
        reset \$interco_company_id \
        expr "\$quote_count+0" \
]

#
# PM Counters (per project)
#
set invoice_pm_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_pm_subtotal \
        reset \$project_manager_id \
        expr "\$invoice_amount+0" \
]

set quote_pm_counter [list \
        pretty_name "Quote Amount" \
        var quote_pm_subtotal \
        reset \$project_manager_id \
        expr "\$quote_amount+0" \
]

set project_count_pm_counter [list \
        pretty_name "Project Count" \
        var project_count_pm_subtotal \
        reset \$project_manager_id \
        expr "\$project_count+0" \
]

set quote_count_pm_counter [list \
        pretty_name "Project Count" \
        var quote_count_pm_subtotal \
        reset \$project_manager_id \
        expr "\$quote_count+0" \
]


#
# Grand Total Counters
#
set invoice_grand_total_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_total \
        reset 0 \
        expr "\$invoice_amount+0" \
]

set quote_grand_total_counter [list \
        pretty_name "Quote Amount" \
        var quote_total \
        reset 0 \
        expr "\$quote_amount+0" \
]

set project_count_grand_total_counter [list \
        pretty_name "Project Count" \
        var project_count_total \
        reset 0 \
        expr "\$project_count+0" \
]

set quote_count_grand_total_counter [list \
        pretty_name "Project Count" \
        var quote_count_total \
        reset 0 \
        expr "\$quote_count+0" \
]



set counters [list \
	$invoice_subtotal_counter \
	$quote_subtotal_counter \
	$project_count_subtotal_counter \
	$quote_count_subtotal_counter \
	$invoice_ag_subtotal_counter \
	$quote_ag_subtotal_counter \
	$project_count_ag_subtotal_counter \
	$quote_count_ag_subtotal_counter \
	$invoice_pm_counter \
	$quote_pm_counter \
	$project_count_pm_counter \
	$quote_count_pm_counter \
	$invoice_grand_total_counter \
	$quote_grand_total_counter \
	$project_count_grand_total_counter \
	$quote_count_grand_total_counter \
	
]


# ------------------------------------------------------------
# Constants
#

set start_years {2000 2000 2001 2001 2002 2002 2003 2003 2004 2004 2005 2005 2006 2006}
set start_months {01 Jan 02 Feb 03 Mar 04 Apr 05 May 06 Jun 07 Jul 08 Aug 09 Sep 10 Oct 11 Nov 12 Dec}
set start_weeks {01 1 02 2 03 3 04 4 05 5 06 6 07 7 08 8 09 9 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19 20 20 21 21 22 22 23 23 24 24 25 25 26 26 27 27 28 28 29 29 30 30 31 31 32 32 33 33 34 34 35 35 36 36 37 37 38 38 39 39 40 40 41 41 42 42 43 43 44 44 45 45 46 46 47 47 48 48 49 49 50 50 51 51 52 52}
set start_days {01 1 02 2 03 3 04 4 05 5 06 6 07 7 08 8 09 9 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19 20 20 21 21 22 22 23 23 24 24 25 25 26 26 27 27 28 28 29 29 30 30 31 31}
set levels {1 "Zeit" 2 "Zeit+Agentur" 3 "Zeit+Agentur+KM" 4 "Zeit+Ag+KM+Proj"} 
set timerangeopt {week "Woche" month "Monat" year "Jahr"}
# ------------------------------------------------------------
# Start Formatting the HTML Page Contents

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format

switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	<td>
	<form>
                [export_form_vars project_id project_manager_id]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>Zeiteintlg</td>
		  <td class=form-widget>
		     [im_select -translate_p 1 timerangeset $timerangeopt $timerangeset]
		  </td>
		</tr>

		<tr>
		  <td class=form-label>Level of Details</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
	
		<tr>
		  <td class=form-label>Start Date</td>
		  <td class=form-widget>
		    <input type=textfield name=start_date value=$start_date>
		  </td>
		</tr>
		<tr>
		  <td class=form-label>End Date</td>
		  <td class=form-widget>
		    <input type=textfield name=end_date value=$end_date>
		  </td>
		</tr>
                <tr>
                  <td class=form-label>Format</td>
                  <td class=form-widget>
                    [im_report_output_format_select output_format $output_format]
                  </td>
                </tr>
		<tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
		</tr>
		</table>
	</form>
	</td>
	<td>
		<table cellspacing=2 width=90%>
		<tr><td>$help_text</td></tr>
		</table>
	</td>
	</tr>
	</table>
	<table border=0 cellspacing=1 cellpadding=1>\n"
    }
}	

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"


set footer_array_list [list]
set last_value_list [list]
set class "rowodd"

ns_log Notice "intranet-reporting/finance-quotes-pos: sql=\n$sql"

db_foreach sql $sql {

        if {"" == $project_id} {
            set project_id 0
            set project_name [lang::message::lookup "" intranet-reporting.No_project "Undefined Project"]
        }

	if {"" == $project_manager_id} {
	    set project_manager_id 0
	    set project_manager_name "No Project Manager"
	}

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	
	im_report_update_counters -counters $counters
	
	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
        ]

        set footer_array_list [im_report_render_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
        ]
}

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1


# Write out the HTMl to close the main report table
# and write out the page footer.
#
switch $output_format {
    html { ns_write "</table>\n[im_footer]\n"}
}

