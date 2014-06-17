# /packages/intranet-cust-fud/www/reports/etm-bh-fordg-verbindlkt.tcl
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
    { start_date "" }
    { end_date "" }
    { level_of_detail 1 }
	 { agent "fud_ford_vat" }
    { output_format "html" }
    { number_locale "" }
    { customer_id:integer 0}
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set current_user_id [ad_maybe_redirect_for_registration]
set menu_label "etm-bh-fordg-verbindlkt"

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


# ------------------------------------------------------------
# Defaults

set rowclass(0) "roweven"
set rowclass(1) "rowodd"

set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set cur_format [im_l10n_sql_currency_format]
set date_format [im_l10n_sql_date_format]
set locale [lang::user::locale]
if {"" == $number_locale} { set number_locale $locale  }

set company_url "/intranet/companies/view?company_id="
set invoice_url "/intranet-invoices/view?invoice_id="
set user_url "/intranet/users/view?user_id="
set this_url [export_vars -base "/intranet-reporting-finance/finance-income-statement" {start_date end_date} ]


# Deal with invoices related to multiple projects
im_invoices_check_for_multi_project_invoices


# ------------------------------------------------------------
# Constants
#



# Show all details for this report (no grouping)
set level_of_detail 1

set agentauswahl {fud_ford "FUD Fordg" fud_ford_vat "FUD Fordg VAT" fud_verb "FUD Verbkt" fud_verb_vat "FUD Verbkt VAT" pan_ford "PAN Fordg" pan_ford_vat "PAN Fordg VAT" pan_verb "PAN Verbkt" pan_verb_vat "PAN Verbkt_VAT" zis_ford "ZIS Fordg" zis_ford_vat "ZIS Fordg VAT" zis_verb "ZIS Verbkt" zis_verb_vat "ZIS Verbkt VAT"} 
# ------------------------------------------------------------
# Argument Checking

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

set page_title "FLL oder VLL laden"
set context_bar [im_context_bar $page_title]
set context ""

set help_text "
<strong>Forderungen oder Verbindlichkeiten innerhalb start-end nach Belegdatum<br>
<nobr>ACHTUNG: Format ist UTF-8 und muss in Excel oder OpenOffice angepasst werden fuer Weiterverarbeitung in BH-Progs...</strong></nobr>
"




# ------------------------------------------------------------
# Set the defaults


db_1row start_date "
select
    date_trunc('WEEK', current_date - 7)::date as last_week_monday
from dual
"
if {"" == $start_date} { 
    set start_date "$last_week_monday"
}


db_1row end_date "
select
	(date_trunc('WEEK', current_date - 7)::date) + 6 as last_week_sunday
from dual
"
if {"" == $end_date} { 
    set end_date "$last_week_sunday"
}


### ------------------------------------------------------------
### Conditional SQL Where-Clause

##set criteria [list]

##if {0 != $customer_id} {
##    lappend criteria "cust.company_id = :customer_id"
##}

##set where_clause [join $criteria " and\n            "]
##if { ![empty_string_p $where_clause] } {
##    set where_clause " and $where_clause"
##}



# ETM: setzen der agentur und FLL/VLL
	set habenkontowert ""
	set sollkontowert ""
	set buchungstextpre ""
	set kostenstelle1wert ""
	set kostenstelle2wert ""
	set template_where ""
	set cust_or_prov ""
	set vatwert "0,0"
   set vat_or_amount ""
	set vat_where ""
	
if { $agent == "fud_ford" } {
							set agent_where "AND c.cost_name LIKE 'I9%'"
							set habenkontowert "'4000'"
							set sollkontowert "NULL"
							set buchungstextpre "'PE '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "c.amount"
							set page_title "FUD Forderungen"
	}	elseif { $agent == "fud_verb" } {
							set agent_where "AND c.cost_name LIKE 'B%'"
							set habenkontowert "NULL"
							set sollkontowert "'5201'"
							set buchungstextpre "'PA '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set template_where "AND im_name_from_id(c.template_id) LIKE 'fud_fl_bill%'"
							set vat_or_amount "c.amount"
							set page_title "FUD Verbindlichkeiten"
	}	elseif { $agent == "pan_ford" } {
							set agent_where "AND c.cost_name LIKE 'I3%'"
							set habenkontowert "'4000'"
							set sollkontowert "NULL"
							set buchungstextpre "'PE '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "c.amount"
							set page_title "PAN Forderungen"
	}	elseif { $agent == "pan_verb" } {
							set agent_where "AND c.cost_name LIKE 'B3%'"
							set habenkontowert "NULL"
							set sollkontowert "'5201'"
							set buchungstextpre "'PA '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set vat_or_amount "c.amount"
							set page_title "PAN Forderungen"
	}	elseif { $agent == "zis_ford" } {
							set agent_where "AND c.cost_name LIKE 'IZ%'"
							set habenkontowert "'4000'"
							set sollkontowert "NULL"
							set buchungstextpre "'PE '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "c.amount"
							set page_title "ZIS Forderungen"
	}	elseif { $agent == "zis_verb" } {
							set agent_where "AND c.cost_name LIKE 'BZ%'"
							set habenkontowert "NULL"
							set sollkontowert "'5201'"
							set buchungstextpre "'PA '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set template_where "AND im_name_from_id(c.template_id) LIKE 'zis_fl_bill%'"
							set vat_or_amount "c.amount"
							set page_title "ZIS Verbindlichkeiten"
	} elseif { $agent == "fud_ford_vat" } {
							set agent_where "AND c.cost_name LIKE 'I9%'"
							set habenkontowert "'3800'"
							set sollkontowert "NULL"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "CASE WHEN c.vat = 8 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 8"
							set page_title "FUD MwSt (Forderungen)"
	}	elseif { $agent == "fud_verb_vat" } {
							set agent_where "AND c.cost_name LIKE 'B%'"
							set habenkontowert "NULL"
							set sollkontowert "'3800'"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set template_where "AND im_name_from_id(c.template_id) LIKE 'fud_fl_bill%'"
							set vat_or_amount "CASE WHEN c.vat = 8 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 8"
							set page_title "FUD MwSt (Verbindlichkeiten)"
	}	elseif { $agent == "pan_ford_vat" } {
							set agent_where "AND c.cost_name LIKE 'I3%'"
							set habenkontowert "'3800'"
							set sollkontowert "NULL"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "CASE WHEN c.vat = 8 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 8"
							set page_title "PAN MwSt (Forderungen)"
	}	elseif { $agent == "pan_verb_vat" } {
							set agent_where "AND c.cost_name LIKE 'B3%'"
							set habenkontowert "NULL"
							set sollkontowert "'3800'"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set vat_or_amount "CASE WHEN c.vat = 8 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 8"
							set page_title "PAN MwSt (Verbindlichkeiten)"
	}	elseif { $agent == "zis_ford_vat" } {
							set agent_where "AND c.cost_name LIKE 'IZ%'"
							set habenkontowert "'3800'"
							set sollkontowert "NULL"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "NULL"
							set kostenstelle2wert "substring(c.cost_name from 2 for 8)"
							set cust_or_prov "im_name_from_id(c.customer_id)"
							set vat_or_amount "CASE WHEN c.vat = 19 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 19"
							set page_title "ZIS MwSt (Forderungen)"
	}	elseif { $agent == "zis_verb_vat" } {
							set agent_where "AND c.cost_name LIKE 'BZ%'"
							set habenkontowert "NULL"
							set sollkontowert "'3800'"
							set buchungstextpre "'VAT '"
							set kostenstelle1wert "substring(c.cost_name from 2 for 8)"
							set kostenstelle2wert "NULL"
							set cust_or_prov "im_name_from_id(c.provider_id)"
							set template_where "AND im_name_from_id(c.template_id) LIKE 'zis_fl_bill%'"
							set vat_or_amount "CASE WHEN c.vat = 19 THEN c.vat * c.amount / 100 ELSE c.amount END"
							set vat_where "AND c.vat = 19"
							set page_title "ZIS MwSt (Verbindlichkeiten)"
	}  else {}


if { ![empty_string_p $template_where] } {
    set template_where "$template_where"
}

if { ![empty_string_p $agent_where] } {
    set agent_where "$agent_where"
}

if { ![empty_string_p $buchungstextpre] } {
	 set buchungstextpre "$buchungstextpre"
}

if { ![empty_string_p $vat_where] } {
    set vat_where "$vat_where"
}
# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#


set sql "

SELECT
	to_char(c.effective_date, 'DD.MM.YYYY') as belegdatum,
	NULL as buchungsdatum,
	NULL as belegnummernkreis,
	c.cost_name as belegnummer,
	$buchungstextpre || $cust_or_prov  as buchungstext,
	to_char($vat_or_amount, :cur_format) as buchungsbetrag,
	$sollkontowert as sollkonto,
	$habenkontowert as habenkonto,
	$vatwert as vat,
	$kostenstelle1wert as kostenstelle_1,
	$kostenstelle2wert as kostenstelle_2,
	c.currency as waehrung
	
FROM 
	im_costs c
WHERE
	 c.effective_date >= to_date(:start_date, 'YYYY-MM-DD')
    and c.effective_date <= to_date(:end_date, 'YYYY-MM-DD')
	 $agent_where
	 $template_where
	 $vat_where
ORDER BY
	c.effective_date
"



set report_def [list \
    group_by customer_id \
    header {
			$belegdatum
			$buchungsdatum
			$belegnummernkreis
			$belegnummer
			$buchungstext
			$buchungsbetrag_pretty
			$sollkonto
			$habenkonto
			$vat
			$kostenstelle_1
			$kostenstelle_2
			$waehrung
    } \
    content {} \
    footer {} \
]




# Global header/footer
set header0 {"Belegdatum" "Buchungsdatum" "Belegnummernkreis" "Belegnummer" "Buchungstext" "Buchungsbetrag" "Sollkonto" "Habenkonto" "Steuerschlüssel" "Kostenstelle 1" "Kostenstelle 2" "Währung"}
set footer0 {}




# ------------------------------------------------------------
# Start formatting the page header
#

# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format

# Add the HTML select box to the head of the page
switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	<td>
	<form>
		[export_form_vars customer_id]
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>Agentur</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 agent $agentauswahl $agent]
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
                    [im_report_output_format_select output_format "" $output_format]
                  </td>
                </tr>
                <tr>
                  <td class=form-label><nobr>Number Format</nobr></td>
                  <td class=form-widget>
                    [im_report_number_locale_select number_locale $number_locale]
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
	<table border=0 cellspacing=3 cellpadding=3>\n"
    }
}


# ------------------------------------------------------------
# Start formatting the report body
#

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"


set footer_array_list [list]
set last_value_list [list]
set class "rowodd"

ns_log Notice "intranet-reporting-finance/finance-income-statement: sql=\n$sql"

db_foreach sql $sql {
     
	set buchungsbetrag_pretty [im_report_format_number $buchungsbetrag $output_format $number_locale]
 
    if {"" == $customer_id} {
	set customer_id 0
	set customer_name [lang::message::lookup "" intranet-reporting.No_customer "Undefined Customer"]

    }

	
    
    im_report_display_footer \
	-output_format $output_format \
	-group_def $report_def \
	-footer_array_list $footer_array_list \
	-last_value_array_list $last_value_list \
	-level_of_detail $level_of_detail \
	-row_class $class \
	-cell_class $class

   
    
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


switch $output_format {
    html { ns_write "</table>\n[im_footer]\n" }
}
