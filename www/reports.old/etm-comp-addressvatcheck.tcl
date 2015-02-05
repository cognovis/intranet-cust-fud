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
    Reporting Tutorial "comp-address-vat-check" Report
    This reports lists all projects in a time interval
    It is one of the easiest reports imaginable...

   
} {
    
    { level_of_detail:integer 3 }
    { customer_id:integer 0 }
	 { user_id 0 }
	 { last_days:integer 30 }
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
set menu_label "etm-comp-addressvatcheck"

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





# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }

if {$last_days < 30} { set last_days 30 }

# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#
# We always need a "page_title".
# The "context_bar" defines the "bread crums" at the top of the
# page that allow a user to return to the home page and to
# navigate the site.
#

set page_title "Fehlende Adress-Daten und USt-IDs"
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>Fehler in der Auflistung bitte webmin@etranslationmanagement.com melden, besten Dank!!!</strong><br>
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
set date_format "DD-MM-YYYY"

# Set URLs on how to get to other parts of the system
# for convenience. (New!)
# This_url includes the parameters passed on to this report.
#
set company_url "/intranet/companies/view?company_id="
set project_url "/intranet/projects/view?view_name=finance&project_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set office_url "/intranet/offices/view?office_id="
set this_url [export_vars -base "/intranet-reporting-finance/fud-paym-due_bypm" {start_date end_date} ]
#set new_company_url "/intranet/biz-card.tcl"
set new_company_url "/intranet/biz-card?form%3Amode=edit&form%3Aid=contact&__confirmed_p=0&__refreshing_p=0&company_name="

# Level of Details
# Determines the LoD of the grouping to be displayed
#
set levels {2 "PM" 3 "PM+Customers"} 

##set user_id $current_user_id

# Last days
set last_days_option { 30 "30" 60 "60" 90 "90" 5000 "5000"}
# ------------------------------------------------------------

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
  im_name_from_id(p.project_lead_id) as cm,
  comp.company_id, 
  o.company_id, 
  comp.vat_number,
  CASE  WHEN comp.vat_number IS NOT NULL AND comp.company_type_id = '11000010' THEN im_name_from_id(comp.company_type_id) || ' UEBERPRUEFEN!!! USTID VORHANDEN!!!' 
	WHEN comp.company_type_id NOT IN (11000011,11000010) THEN 'KUNDENTYP SPEZIFIZIEREN (Privat oder Geschaeftskunde)' ELSE im_name_from_id(comp.company_type_id) 
    END as comptype,
  comp.company_type_id,
  CASE 	WHEN comp.company_type_id != '11000010' AND comp.vat_number IS NULL AND p.project_nr LIKE 'Z%' AND o.address_country_code != 'de' THEN 'UST-ID FEHLT!' 
	ELSE comp.vat_number
   END as ustid,
  comp.company_name, 
  comp.primary_contact_id, 
  p.project_nr as project,
  to_char(p.start_date, 'DD.MM.YYYY'),
  p.start_date,
  CASE 	WHEN o.address_line1 IS NULL THEN 'STR U. NR FEHLT'
	WHEN o.address_line1  LIKE '%@%' THEN 'KEINE EMAIL ALS ADRESSE!!!-->'  || o.address_line1
	ELSE o.address_line1
   END as strasse,  
   o.address_line2,  
  CASE  WHEN o.address_city IS NULL THEN 'ORT FEHLT'
	ELSE o.address_city
   END as stadt, 
  CASE  WHEN o.address_postal_code IS NULL THEN 'PLZ FEHLT'
	ELSE o.address_postal_code
   END as plz, 
  CASE  WHEN o.address_country_code IS NULL THEN 'LAND FEHLT'
	ELSE o.address_country_code
   END as countrycode, 
  o.contact_person_id, 
  o.office_name,
  o.office_id,
  p.project_id,
  p.project_nr,
  o.address_line1,
  o.address_city,
  o.address_postal_code,
  o.address_country_code,
  comp.company_type_id
FROM 
  public.im_offices o, 
  public.im_companies comp
  LEFT OUTER JOIN im_projects p ON (comp.company_id = p.company_id)
WHERE 
  o.company_id = comp.company_id
  AND p.project_nr NOT LIKE '1%'
  AND p.project_name NOT LIKE '%p'
  AND comp.company_type_id NOT IN ('53')
  AND p.project_lead_id != '624'
  AND p.start_date > current_date - 160
  --AND p.start_date > current_date - $last_days
  AND (CASE
	WHEN 	(p.project_nr LIKE 'Z%' AND comp.company_type_id != '11000010' AND comp.vat_number IS NULL AND o.address_country_code != 'de')
		OR
		(comp.vat_number LIKE 'DE%' and o.address_country_code != 'de')
		OR
		o.address_line1  LIKE '%@%'
		OR 
		o.address_line1 IS NULL
		OR
		o.address_city IS NULL
		OR
		o.address_postal_code IS NULL
		OR
		o.address_country_code IS NULL
		OR
		comp.company_type_id = '57'
	THEN true ELSE false
	END
	) <> 'false'
	$where_clause
ORDER BY p.project_lead_id, comp.company_id

"






# ------------------------------------------------------------
# Report Definition
#
# Reports are defined in a "declarative" style. The definition
# consists of a number of fields for header, lines and footer.

# Global Header Line
set header0 {
	"KM" 
	"Kunde" 
	"Projekt<br>Nr" 
	"USt-ID" 
	"Kd-Typ"
	"StrNr"
	"PLZ"
	"Ort"
	"Land"
	"OfficeName"
	
	
}


set report_def [list \
    group_by cm \
    header {
	"
	<b>$cm</b>"
    } \
        content [list \
            group_by company_id \
            header {} \
	    content [list \
		    header {
			""
			"<b><a href=$company_url$company_id>$company_name</a></b>"
			"<b><a href=$project_url$project_id>$project_nr</a></b>"
			$ustid
			$comptype
			$strasse
			$plz
			$stadt
			$countrycode
			"<b><a href=$office_url$office_id>$office_name</a></b>"
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


#set ttt {
#		"<nobr><i>$po_per_quote_perc</i></nobr>"
#		"<nobr><i>$gross_profit</i></nobr>"
#}


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
<!-- TODO LETZTE xx TAGE 		
	<tr>
		  <td class=form-label>Last</td>
		  <td class=form-widget>
		    [im_select  last_days_option $last_days]
		  </td>
		</tr>
-->
		<tr>
			<td>CM</td>		  
			<td class=form-widget>
		    [im_user_select -include_empty_p 1 -group_id 467  user_id  $user_id]
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




##ETM: vat-id check ZIS	
##ETM: check if UID is DE but country is not DE
if {"11000010" != $company_type_id && "" == $vat_number && [regexp {^[Z*]} $project_nr]} {
	    set ustid "<font color=red>$ustid</font>"
}	else { 
			set ustid $vat_number 
			}

if {"de" != $address_country_code && [regexp {^[DE*]} $vat_number]} {
	    set ustid "<font color=red>$ustid ist Deutsch, Adresse aber nicht...<br><b><a href=$new_company_url$company_name>HIER neue Firma anlegen!!!!</a></b></font>"
}



##ETM: check in comp-type: privat
if {"57"  == $company_type_id} {
	    set comptype "<font color=red>$comptype</font>"
}

##ETM: email check in strasse	
if {[regexp {[*@*]} $address_line1 ]} {
	    set strasse "<font color=red>$strasse</font>"
}

##ETM: check in strasse	
if {"" == $address_line1 } {
	    set strasse "<font color=red>$strasse</font>"
}

##ETM: check in plz	
if {"" == $address_postal_code } {
	    set plz "<font color=red>$plz</font>"
}

##ETM: check in land	
if {"" == $address_country_code } {
	    set countrycode "<font color=red>$countrycode</font>"
}

 
##ETM: check in stadt	
if {"" == $address_city } {
	    set stadt "<font color=red>$stadt</font>"
}



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

