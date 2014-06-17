# /packages/intranet-reporting-finance/www/fud-accountancy-openBills.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.




# ------------------------------------------------------------
# Page Contract 
#
# FUD - Accountancy - Open Bills
#

ad_page_contract {
    FUD - Accountancy - Open Bills.

    @param start_date Start date (YYYY-MM-DD format) 
    @param end_date End date (YYYY-MM-DD format) 
} {
    { start_date "2009-07-01" }
    { end_date "2099-12-31" }
    { level_of_detail:integer 3 }
    { provider_id:integer 0 }
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
set menu_label "fud-accountancy-openBills"

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
set read_p "t"

# Write out an error message if the current user doesn't
# have read permissions and abort the execution of the
# current screen.
if {![string equal "t" $read_p]} {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}



# ------------------------------------------------------------
# Check Parameters (New!)
#
# Check that start_date and end_date have correct format.
# We are using a regular expression check here for convenience.

if {![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
    ad_script_abort
}

if {![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
    ad_script_abort
}

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

set page_title "Offene Bills FLer"
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>Open Bills</strong><br>
	Start und End-Datum grenzen die Auswahl nach Erstellungsdatum der Bill ein!
	
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
set paym_url "/intranet-payments/new?cost_id="
set paymreturn_url "&return_url=%2fintranet-invoices%2fview%3finvoice%255fid%3d"
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting-finance/fud-accountancy-openBills" {start_date end_date} ]

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels {2 "Freelancer" 3 "Freelancer+Bills"} 



# ------------------------------------------------------------
# Report SQL - This SQL statement defines the raw data 
# that are to be shown.
#
# This section is usually the starting point when starting 
# any new report.
# Once your SQL is fine you you start adding formatting, 
# grouping and filters to create a "real-world" report.
#

set provider_sql ""
if {0 != $provider_id} {
    set provider_sql "and c.provider_id = :provider_id\n"
}


set report_sql "
	select
	 c.note as rgnamefler,
	 c.project_id,
	 to_char(c.effective_date, :date_format),
	 c.cost_name as bill_nr,
	 c.cost_id as invoice_id,
	 im_project_nr_from_id(c.project_id) as project_nr, 
	 im_company__name(c.provider_id) as provider_name,
	 c.provider_id,
	 to_char(c.effective_date, 'DD.MM.YYYY') as rgdatum,
	 c.amount::numeric (12,2) as amount,
	 c.currency as cur,
	 c.paid_amount::numeric (12,2) as paid_amount,
	 c.paid_currency as paid_cur
	from	
	 im_costs c
	where	
		c.cost_type_id = 3704  
		AND c.paid_amount is null
		AND im_company__name(c.provider_id) <> 'Your company'
		and c.effective_date >= :start_date
		and c.effective_date <= :end_date
		$provider_sql
	
	order by 
		provider_name asc, effective_date, project_id
	
"



# ------------------------------------------------------------
# Report Definition
#
# Reports are defined in a "declarative" style. The definition
# consists of a number of fields for header, lines and footer.

# Global Header Line
set header0 {
	"FLer" 
	"Rechnungs-Name"
	"Datum"
	"Bill-Name"
	""
	"Summe"	
	"Bezahlt"
	
	
	
}

# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
#
set report_def [list \
    group_by provider_id \
    header {
	"\#colspan=10 <b><a href=$company_url$provider_id>$provider_name</a></b>"
	
    } \
        content [list \
            group_by rgdatum \
            header {
            ""
            "\#colspan=9 <strong>$rgnamefler</strong>" 
            } \
	    content [list \
	    	header {
			""
			""
			$rgdatum
			"<a href='$invoice_url$invoice_id'>$bill_nr   </a> &nbsp;&nbsp;&nbsp;&nbsp;"
			"<a href='$paym_url$invoice_id$paymreturn_url$invoice_id'><strong>Bezahlung anlegen</strong></a>"
			"$cur<nobr> $amount"
			"$paid_cur<nobr> $paid_amount"

		    } \
		    content {} \
	    ] \
            footer {} \
    ] \
    footer {  
		""
		""
		""
		""
		"<nobr><i>Total FLer</i></nobr>"
		"<nobr><i>$bill_subtotal</i></nobr>"
		"" 
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
	"<br><b>Total:</b>"
	"<br><b>$bill_total</b>"
	""
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


set bill_subtotal_counter [list \
        pretty_name "Bill Amount" \
        var bill_subtotal \
        reset \$provider_id \
        expr "\$amount+0" \
]
#
# Grand Total Counters
#

set bill_grand_total_counter [list \
        pretty_name "Bill Amount" \
        var bill_total \
        reset 0 \
        expr "\$amount+0" \
]







set counters [list \
	$bill_subtotal_counter \
	$bill_grand_total_counter \
]

# Set the values to 0 as default
set bill_total 0


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
		<tr>
		  <td><nobr>Start Date:</nobr></td>
		  <td><input type=text name=start_date value='$start_date'></td>
		</tr>
		<tr>
		  <td>End Date:</td>
		  <td><input type=text name=end_date value='$end_date'></td>
		</tr>
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
	<table border=0 cellspacing=1 cellpadding=1>
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

	# Restrict the length of the project_name to max.
	# 40 characters. (New!)
	#set project_name [string_truncate -len 40 $project_name]

	im_report_display_footer \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	im_report_update_counters -counters $counters

	# Calculated Variables (New!)
#	set po_per_quote_perc "undef"
#	if {[expr $quote_subtotal+0] != 0} {
#	  set po_per_quote_perc [expr int(10000.0 * $po_subtotal / $quote_subtotal) / 100.0]
#	  set po_per_quote_perc "$po_per_quote_perc %"
#	}
#	set gross_profit [expr $invoice_subtotal - $bill_subtotal]

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

