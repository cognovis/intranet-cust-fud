# /packages/intranet-reporting-finance/www/fud-finance-weeks.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.


# ------------------------------------------------------------
# Page Contract 
#
# FUD KW-REPORT basiert auf report-tut05
#

ad_page_contract {
    FUD weekly Report
    This reports lists all projects in a time interval of weeks
    It is one of the easiest reports imaginable...

    @param year Year (YYYY format) 
    @param week Week (WW format) 
} {
    { year "" }
    { week "" }
   
    { start_date "" }
    { end_date "2099-12-31" }
    { level_of_detail:integer 3 }
    { customer_id:integer 0 }
}


# ------------------------------------------------------------
# Security (New!)
#
# The access permissions for the report are taken from the
# "im_menu" Menu Items in the "Reports" section that link 
# to this report. It's just a convenient way to handle 
# security, that avoids errors (different rights for the 
# Menu Item then for the report) and redundancy.

# What is the "label" of the Menu Item linking to this report?
set menu_label "fud-reporting-finance-weeks"

# Get the current user and make sure that he or she is
# logged in. Registration is handeled transparently - 
# the user is redirected to this URL after registration 
# if he wasn't logged in.
set current_user_id [ad_maybe_redirect_for_registration]

# Determine whether the current_user has read permissions. 
# "db_string" takes a name as the first argument 
# ("report_perms") and then executes the SQL statement in 
# the second argument. 
# It returns an error if there is more then one result row.
# im_object_permission_p is a PlPg/SQL procedure that is 
# defined as part of ]project-open[.
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

# For testing - set manually
#set read_p "t"

# Write out an error message if the current user doesn't
# have read permissions and abort the execution of the
# current screen.
if {![string equal "t" $read_p]} {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

# ------------------------------------------------------------
# Set the default start and end date

set days_in_past 0

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
    set end_date "$todays_year-$todays_month-$todays_day"
}


db_1row todays_week "
select
	
	(SELECT EXTRACT (WEEK FROM sysdate::date)) AS todays_week
from dual
"


#if {"" == $year} { 
#    set year "$todays_year"
#}

#if {"" == $week} { 
#    set week "$todays_week"
#}


# ------------------------------------------------------------
# Check Parameters (New!)
#
# Check that start_date and end_date have correct format.
# We are using a regular expression check here for convenience.


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


#if {![regexp {[0-9][0-9][0-9][0-9]} $year]} {
#    ad_return_complaint 1 "Year doesn't have the right format.<br>
#    Current value: '$year'<br>
#    Expected format: 'YYYY'"
#    ad_script_abort
#}

#if {![regexp {[0-9][0-9]} $week]} {
#    ad_return_complaint 1 "Week doesn't have the right format.<br>
#    Current value: '$week'<br>
#    Expected format: 'WW'"
#    ad_script_abort
#}

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }




# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#
# We always need a "page_title".
# The "context_bar" defines the "bread crums" at the top of the
# page that allow a user to return to the home page and to
# navigate the site.
# Every reports should contain a "help_text" that explains in
# detail what exactly is shown. Reports can get very messy and
# it can become very difficult to interpret the data shown.
#

set page_title "Fud-Finance-Weeks"
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>Orders per week</strong><br>
	(Gesamtjahresueberblick nach KWs<br>Leider (noch) keine Anzeige in den (Sub)Totalwerten fuer POs und Bills von gecancelten Auftraegen, bei denen aber trotzdem Kosten anfallen...)
	<br>
	<br>
	<br>
	<br>
	<a href=http://fudproman.com/intranet-cust-fud/reports/fud-finance-weeks_qt>Quotes per week</a>
"


# ------------------------------------------------------------
# Default Values and Constants
#
# In this section we define constants and default variables
# that are used in the sections further below.
#

# Default report line formatting - alternating between the
# CSS styles "roweven" (grey) and "rowodd" (lighter grey).
#
set rowclass(0) "roweven"
set rowclass(1) "rowodd"

# Variable formatting - Default formatting is quite ugly
# normally. In the future we will include locale specific
# formatting. 
#
set currency_format "999,999,999.09"
set date_format "YYYY-MM-DD"

# Set URLs on how to get to other parts of the system
# for convenience. (New!)
# This_url includes the parameters passed on to this report.
#
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?project_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting-finance/fud-finance-weeks.tcl
" {start_date end_date} ]

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels {2 "Weeks only" 3 "Weeks+Projects"} 

#set weeks {01 1 02 2 03 3 04 4 05 5 06 6 07 7 08 8 09 9 10 10 11 11 12 12 13 13 14 14 15 15 16 16 17 17 18 18 19 19 20 20 21 21 22 22 23 23 24 24 25 25 26 26 27 27 28 28 29 29 30 30 31 31 32 32 33 33 34 34 35 35 36 36 37 37 38 38 39 39 40 40 41 41 42 42 43 43 44 44 45 45 46 46 47 47 48 48 49 49 50 50 51 51 52 52}

# ------------------------------------------------------------
# Report SQL - This SQL statement defines the raw data 
# that are to be shown.
#
# This section is usually the starting point when starting 
# any new report.
# Once your SQL is fine you you start adding formatting, 
# grouping and filters to create a "real-world" report.
#

set customer_sql ""
if {0 != $customer_id} {
    set customer_sql "and p.company_id = :customer_id\n"
}

# This version of the select query uses a join with 
# im_companies on (p.company_id = company.company_id).
# This join is possible, because the p.company_id field
# is a non-null field constraint via referential integrity
# to the im_companies table.
# In the absence of such strong integrity contraints you
# will have to use "LEFT OUTER JOIN"s instead. (New!)
#
set report_sql "
	select
		p.*,
		cust.company_id as customer_id,
		cust.company_path as customer_nr,
		cust.company_name as customer_name,

		to_char(p.start_date, 'YYYY') as year,
		(SELECT EXTRACT (WEEK FROM p.start_date)) AS week,
		to_char(p.start_date, :date_format) as start_date_formatted,
		to_char(p.end_date, :date_format) as end_date_formatted,
		im_name_from_user_id(p.project_lead_id) as project_lead_name,

		to_char(p.cost_invoices_cache, :currency_format) as invoices,
		to_char(p.cost_quotes_cache, :currency_format) as quotes,
		to_char(p.cost_purchase_orders_cache, :currency_format) as pos,
		to_char(p.cost_bills_cache, :currency_format) as bills
		
		--count(p.project_id) as project_id
	from
		im_projects p,
		im_companies cust
	where
		p.company_id = cust.company_id
		and (p.project_nr LIKE ('9%') OR p.project_nr LIKE ('Z%') OR p.project_nr LIKE ('313%'))
		and parent_id is null
		and p.start_date >= :start_date
		and p.start_date <= :end_date
		--and (SELECT EXTRACT (WEEK FROM p.start_date)) in (:week)
		--and (SELECT EXTRACT (YEAR FROM p.start_date)) = :year
		-- $customer_sql
	order by
		
		(SELECT EXTRACT (WEEK FROM p.start_date)) DESC,
		p.start_date DESC,
		(SELECT EXTRACT (WEEK FROM p.start_date)) DESC,
		lower(p.project_nr) DESC
"



# ------------------------------------------------------------
# Report Definition
#
# Reports are defined in a "declarative" style. The definition
# consists of a number of fields for header, lines and footer.

# Global Header Line
set header0 {
	"Year"	
	"KW" 
	"Project" 
	"Cust" 
	"Project<br>Manager" 
	"StartDate"
	"Invoices"
	"Quotes"
	"POs"
	"Bills"
	
}

# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by week \
    header {
	<b>$year</b>
	"\#colspan=9 
	<b>$week</b>"
    } \
        content [list \
            group_by project_id \
            header { } \
	    content [list \
		    header {
			""
			""
			"<a href='$project_url$project_id'>$project_name</a>"
			"<b><a href=$company_url$customer_id>$customer_name</a></b>"
			$project_lead_name
			$start_date_formatted
			$invoices
			$quotes
			$pos
			$bills
		    } \
		    content {} \
	    ] \
            footer {
            } \
    ] \
    footer {  
    		""
		""
		""
		""
		""
		""
		"<nobr><i>$invoice_subtotal</i></nobr>" 
		"<nobr><i>$quote_subtotal</i></nobr>" 
		"<nobr><i>$po_subtotal</i></nobr>"
		"<nobr><i>$bill_subtotal</i></nobr>"   
     } \
]


set ttt {
		"<nobr><i>$po_per_quote_perc</i></nobr>"
		"<nobr><i>$gross_profit</i></nobr>"
}


# Global Footer Line
set footer0 {
	"" 
	"" 
	"" 
	"" 
	""
        "<br><b>Total:</b>"
	"<br><b>$invoice_total</b>"
	"<br><b>$quote_total</b>"
	
	"<br><b>$po_total</b>"
	"<br><b>$bill_total</b>"
	
}


# ------------------------------------------------------------
# Counters (New!)
#
# Counters are used to present totals and subtotals.
# Counters consist of several parts:
#	- A "pretty_name"
#	- A "var" variable. This variable can be used
#	  in the report to refer to the value of the counter.
#	- A "reset" condition. 
#	  The value of the counter will be reset to 0
#	  every time the value of this expression _changes_.
#	  This allows to define several levels of counters.
#	- An "expr" expression that is to be evaluated.
#
# The counters are updated inside the Main Report Loop with
# variables from the SQL query.
#
# Please note the "+0" part in all the counters. This is
# a trick to deal with possible null (empty) values of the
# numeric fields. In this case the "+0" is just evaluated
# to "0".

#
# Subtotal Counters (per project)
#

set invoice_subtotal_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_subtotal \
        reset \$week \
        expr "\$cost_invoices_cache+0" \
]

set quote_subtotal_counter [list \
        pretty_name "Quote Amount" \
        var quote_subtotal \
        reset \$week \
        expr "\$cost_quotes_cache+0" \
]

set bill_subtotal_counter [list \
        pretty_name "Bill Amount" \
        var bill_subtotal \
        reset \$week \
       expr "\$cost_bills_cache+0" \
]

set po_subtotal_counter [list \
        pretty_name "Po Amount" \
        var po_subtotal \
        reset \$week \
        expr "\$cost_purchase_orders_cache+0" \
]

#set invoice_subtotal_counter [list \
#	pretty_name "Invoice Amount" \
#	var invoice_subtotal \
#	reset \$project_id \
#	expr "\$paid_invoice_amount+0" \
#]

#
# Grand Total Counters
#
set invoice_grand_total_counter [list \
        pretty_name "Invoice Amount" \
        var invoice_total \
        reset 0 \
        expr "\$cost_invoices_cache+0" \
]

set quote_grand_total_counter [list \
        pretty_name "Quote Amount" \
        var quote_total \
        reset 0 \
        expr "\$cost_quotes_cache+0" \
]



set bill_grand_total_counter [list \
        pretty_name "Bill Amount" \
        var bill_total \
        reset 0 \
        expr "\$cost_bills_cache+0" \
]



set po_grand_total_counter [list \
        pretty_name "Po Amount" \
        var po_total \
        reset 0 \
        expr "\$cost_purchase_orders_cache+0" \
]

##FUD add project-counter
set project_grand_total_counter [list \
        pretty_name "Project Count" \
        var project_total \
        reset 0 \
        expr "\$project_nr+0" \
]

set counters [list \
	$invoice_subtotal_counter \
	$quote_subtotal_counter \
	$bill_subtotal_counter \
	$po_subtotal_counter \
	$invoice_grand_total_counter \
	$quote_grand_total_counter \
	$bill_grand_total_counter \
	$po_grand_total_counter \
]


# Set the values to 0 as default (New!)
set invoice_total 0
set quote_total 0

set bill_total 0
set po_total 0



# ------------------------------------------------------------
# Start Formatting the HTML Page Contents
#
# Writing out a report can take minutes and hours, so we are
# writing out the HTML contents incrementally to the HTTP 
# connection, allowing the user to read the first lines of the
# report (in particular the help_text) while the rest of the
# report is still being calculated.
#

# Write out the report header with Parameters
# We use simple "input" type of fields for start_date 
# and end_date with default values coming from the input 
# parameters (the "value='...' section).
#

#
ad_return_top_of_page "
	[im_header]
	[im_navbar]
	
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td width='30%'>
		<!-- 'Filters' - Show the Report parameters -->
		<form>
		<table cellspacing=2>
		<tr class=rowtitle>
		  <td class=rowtitle colspan=2 align=center>Filters</td>
		</tr>
		 
		<tr>
		  <td>Level of<br>Details</td>
		  <td>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
		
<!--
		<tr>
		  <td><nobr>Year:</nobr></td>
		  <td><input type=text name=year value='$year'></td>
		</tr>
		<tr>
-->
		  <td><nobr>Start:</nobr></td>
		  <td><input type=text name=start_date value='$start_date'></td>
		</tr>
		<tr>

		  <td><nobr>End:</nobr></td>
		  <td><input type=text name=end_date value='$end_date'></td>
		</tr>
		<!--
		<tr>
		  <td>Week:</td>
		  <td><input type=text name=week value='$week'></td>
		</tr>
		-->
		<tr>
		  <td</td>
		  <td><input type=submit value='Submit'></td>
		</tr>
		</table>
		</form>
	  </td>
	  <td align=center>
	
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	

	  </td>
	</tr>
	</table>
	
	<!-- Here starts the main report table -->
	<table border=0 cellspacing=2 cellpadding=1>
"

# The following report loop is "magic", that means that 
# you don't have to fully understand what it does.
# It loops through all the lines of the SQL statement,
# calls the Report Engine library routines and formats 
# the report according to the report_def definition.

set footer_array_list [list]
set last_value_list [list]

im_report_render_row \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set counter 0
set class ""
db_foreach sql $report_sql {

	# Select either "roweven" or "rowodd" from
	# a "hash", depending on the value of "counter".
	# You need explicite evaluation ("expre") in TCL
	# to calculate arithmetic expressions. 
	set class $rowclass([expr $counter % 2])
	
	
	##FUD: if project_status_id is canceled "83" 	13732.31 	
	if {"83" == $project_status_id} {
	    set project_nr "<font color=red><s>$project_nr</s> canceled</font>"
	    set customer_name "<font color=red><s>$customer_name</s></font>"
	    set project_lead_name "<font color=red><s>$project_lead_name</s></font>"
	    set invoices "<font color=red><s>$invoices</s></font>"
	    set quotes "<font color=red><s>$quotes</s></font>" 
	    
	    #set quote_subtotal_counter [expr "\$quote_subtotal_counter-\$cost_quotes_cache"]
	    
	}


	##FUD: if invoice is 0.00 then color->red
	
	if { "0.00" == $invoices } {
	    set invoices "<font color=red>$invoices</font>"
	}	
	# Restrict the length of the project_name to max.
	# 40 characters. (New!)
	set project_name [string_truncate -len 40 $project_name]

	im_report_display_footer \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	
	if {"83" != $project_status_id} {
	im_report_update_counters -counters $counters
	}
	# Calculated Variables (New!)
	set po_per_quote_perc "undef"
	if {[expr $quote_subtotal+0] != 0} {
	  set po_per_quote_perc [expr int(10000.0 * $po_subtotal / $quote_subtotal) / 100.0]
	  set po_per_quote_perc "$po_per_quote_perc %"
	}
	set gross_profit [expr $invoice_subtotal - $bill_subtotal]

	set last_value_list [im_report_render_header \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	set footer_array_list [im_report_render_footer \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	incr counter
}

im_report_display_footer \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1


# Write out the HTMl to close the main report table
# and write out the page footer.
#
ns_write "
	</table>
	[im_footer]
"

