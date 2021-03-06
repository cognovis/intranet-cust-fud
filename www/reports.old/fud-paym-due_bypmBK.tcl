# /intranet-reporting-finance/fud-paym-due.tcl
#
# Copyright (c) 2003-2006 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.



# ------------------------------------------------------------
# Page Contract 
#


ad_page_contract {
    Reporting Tutorial "projects-ma" Report
    This reports lists all projects in a time interval
    It is one of the easiest reports imaginable...

    @param start_date Start date (YYYY-MM-DD format) 
    @param end_date End date (YYYY-MM-DD format) 
} {
    { start_date "2005-01-01" }
    { end_date "2099-12-31" }
    { level_of_detail:integer 3 }
    { customer_id:integer 0 }
	 { user_id 0 }
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
set menu_label "fud-paym-due-bypm"

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
#

set page_title "Payment Past Due by cm"
set context_bar [im_context_bar $page_title]


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
set date_format "DD-MM-YYYY"

# Set URLs on how to get to other parts of the system
# for convenience. (New!)
# This_url includes the parameters passed on to this report.
#
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?view_name=finance&project_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting-finance/fud-paym-due_bypm" {start_date end_date} ]

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels {2 "PM" 3 "PM+Customers"} 



# ------------------------------------------------------------
# Conditional SQL Where-Clause
#

set criteria [list]

if {[info exists user_id] && 0 != $user_id && "" != $user_id} {
    lappend criteria "p.project_lead_id = :user_id"
}

set where_clause [join $criteria " and\n            "]
if { ![empty_string_p $where_clause] } {
    set where_clause " and $where_clause"
}
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


# cost_type_id = 3700 -> invoices only
# c.cost_status_id not in 
# 3816 -> ?
# 3818 -> ?
# 3802;"Created"
# 3804;"Outstanding"
# 3806;"Past Due"
# 3808;"Partially Paid"
# 3810;"Paid"
# 3814;"Filed"
# 11000162;"Outstanding Prepaid"
# 11000163;"Transfer voucher received"
# 11000197;"Canceled"
#)

## project_status
##11000001;"To Proceed"
##76;"Open"
##75;"Quote Out"
##11000002;"Proceeding"
##11000003;"Ready for QM"
##73;"Qualifying"
##74;"Quoting"
##81;"Closed"
##72;"Inquiring"
##71;"Potential"
##79;"Invoiced"
##78;"Delivered"
##11000014;"Ready for Delivery"
##11000015;"QM...proceeding"
##11000009;"Accepted"
##77;"Declined"
##83;"Canceled"
##11000007;"NoAnswer"
##11000187;"not assigned"
##11000124;"QT_closed"
##82;"Deleted"


set report_sql "
SELECT 
  person__name(p.project_lead_id) as cm,
  im_company__name(c.customer_id) as customer_name,  
  p.project_nr as project_nr,
  c.cost_name as cost_name, 
  im_project__name(p.project_id) as project_name, 
  to_char(c.effective_date, :date_format) as invoice_date, 
  c.payment_days as payment_days, 
  to_char(c.effective_date::date + c.payment_days, :date_format) as deadline, 
  (current_date - (c.effective_date::date + c.payment_days)) as days_past_due,
  to_char(c.amount, :currency_format) as amount,
  c.currency as currency, 
  to_char(c.paid_amount, :currency_format) as paid_amount, 
  c.paid_currency as paid_currency, 
  c.project_id, 
  c.cost_id,
  c.cost_nr, 
  p.company_id, 
  im_category_from_id(p.project_status_id) as project_status,
  im_category_from_id(c.cost_status_id) as cost_status
FROM 
  public.im_costs c, 
  public.im_projects p
WHERE 
  c.project_id = p.project_id
  AND p.project_nr NOT LIKE ('1%') 
  AND  c.cost_type_id = 3700 
  AND (c.paid_amount is NULL OR c.paid_amount < c.amount)
  AND  (p.project_status_id != '83' OR c.cost_status_id != '11000197')
  AND c.cost_status_id != '11000203'
  AND  c.amount > 0
  AND  (c.effective_date::date + c.payment_days +10) < current_date
  $where_clause
 ORDER BY (cm) ASC, (customer_name) ASC, (project_name) ASC, coalesce(c.amount,0) DESC
"






# ------------------------------------------------------------
# Report Definition
#
# Reports are defined in a "declarative" style. The definition
# consists of a number of fields for header, lines and footer.

# Global Header Line
set header0 {
	"CM" 
	"Cust" 
	"Project<br>No" 
	"Invoice<br>No" 
	"Invoice-Date"
	"Paym days"
	"Deadline__"
	"Days<br>past due"
	"Amount"
	"Curr"
	"Paid"
	"Curr"
	"Project Status"
	"Cost Status"
	
	
}


set report_def [list \
    group_by cm \
    header {
	"
	<b>$cm</b>"
    } \
        content [list \
            group_by customer_id \
            header {} \
	    content [list \
		    header {
			""
			"<b><a href=$company_url$company_id>$customer_name</a></b>"
			"<b><a href=$project_url$project_id>$project_nr</a></b>"
			"<b><a href=$invoice_url$cost_id>$cost_name</a></b>"
			
			$invoice_date
			$payment_days
			$deadline
			$days_past_due
			$amount
			$currency
			$paid_amount
			$paid_currency
			$project_status
			$cost_status
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
		"" 
		"" 
		"" 
		"" 
		""
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
	""
	""
	""
	""
	""
	""
}



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
		  <td><nobr>Start Date:</nobr></td>
		  <td><input type=text name=start_date value='$start_date'></td>
		</tr>
		<tr>
		  <td>End Date:</td>
		  <td><input type=text name=end_date value='$end_date'></td>
		</tr>
		<tr>
			<td>CM</td>		  
			<td class=form-widget>
		    [im_user_select -include_empty_p 1 -group_id 467 user_id $user_id]
		  </td>
   	</tr>
		<tr>
	       <td class=form-label>Company</td>
	       <td class=form-widget>
	            [im_company_select -include_empty_name "All"  customer_id $customer_id "" "Customer" "deleted"]
	       </td>
	   </tr>
		<tr>
		  <td</td>
		  <td><input type=submit value='Submit'></td>
		</tr>
		</table>
		</form>
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
	set project_name [string_truncate -len 40 $project_name]

	im_report_display_footer \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

##	im_report_update_counters -counters $counters

#	# Calculated Variables (New!)
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

