# /packages/intranet-reporting-finance/www/finance-income-statement.tcl
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
	 { letzte_kto_nr:integer "" }
	 { agent "" }
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
set menu_label "etm-compdwld"

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

set agentauswahl {fud "FUD" pan "PAN" zis "ZIS"} 
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
# ETM: check - Kto-Nr muss aus Ziffern bestehen und positv-integer sein
if {"" != $letzte_kto_nr && ![regexp {^[0-9]*$} $letzte_kto_nr] } {
    ad_return_complaint 1 "Kto-Nr muss aus Zahlen bestehen.<br>
    Eingabe war:  <font color=red>   $letzte_kto_nr</font>"
}
# ETM: check - Kto-Nr muss aus Ziffern bestehen und positv-integer sein
if {"" != $letzte_kto_nr && [regexp {^[0][0-7]*$} $letzte_kto_nr] } {
    ad_return_complaint 1 "Kto-Nr darf nicht mit 0 beginnen.<br>
    Eingabe war:  <font color=red>   $letzte_kto_nr</font>"
}
# ------------------------------------------------------------





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

#if {"" == $letzte_kto_nr} { 
#    set letzte_kto_nr 0
#}

# Page Settings

set page_title "Neue Kunden: 1. Rg. zwischen $start_date und $end_date"
set context_bar [im_context_bar $page_title]
set context ""

set help_text "
<strong>Firmen innerhalb start-end nach Datum der ersten Rechnung:<br>
<nobr>ACHTUNG: Format ist UTF-8 ...wichtig fuer Weiterverarbeitung in BH-Progs...</strong></nobr>
<br><br>
Im Feld <strong>Letzte Kto-Nr aus BH</strong> kann die Kontonummer des letzten dort eingetragenen Kunden angegeben werden, damit in dieser (Import-)Tabelle die weitere Kontenreihenfolge vorgetragen wird.
"





### ------------------------------------------------------------
### Conditional SQL Where-Clause

# ETM: setzen der agentur
	if { $agentauswahl == "fud" } {
							set agent_where "AND c.cost_name LIKE 'I9%'"
	}	elseif { $agent == "pan" } {
							set agent_where "AND c.cost_name LIKE 'I3%'"
	}	elseif { $agent == "zis" } {
							set agent_where "AND c.cost_name LIKE 'IZ%'"
	}  else { 			set agent_where ""
	}

# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#


set sql "
SELECT DISTINCT ON  (o.company_id) 
  ROW_NUMBER () over (order by o.company_id) as kontonummer, 
  im_name_from_id(o.company_id) as kontobezeichnung,
  o.company_id as kundennummer,
  NULL as anrede,
  im_name_from_id(o.company_id) as firma,
  NULL as name,
  NULL as vorname,
  NULL as zusatz,
  o.address_country_code as land,
  o.address_line1 as strasse,
  o.address_postal_code as plz,
  o.address_city as ort,
  NULL as ansprechpartner,
  o.phone as telefon1,
  NULL as telefon2,
  o.fax as telefax,
  NULL as email,
  NULL as bankleitzahl,
  NULL as bankkonto,
  NULL as bic,
  NULL as iban,
  NULL as bankbezeichnung,
  CASE 
	WHEN comps.payment_days = 30 THEN '30'	
	ELSE '10'
  END as zahlungsziel,
  '0,00' as skonto,
  NULL as skonto_ziel,
  NULL as einzugsermaechtigung
FROM 
  (SELECT DISTINCT ON (c.customer_id) 
   c.customer_id, 
   c.effective_date,
   c.payment_days,
   c.cost_name
   FROM im_costs c, im_companies comp
   WHERE  c.customer_id = comp.company_id AND
	  c.cost_type_id = '3700' 
	  $agent_where
   GROUP BY c.customer_id, c.effective_date,c.payment_days,c.cost_name
   ORDER BY c.customer_id, c.effective_date) as comps
  LEFT OUTER JOIN 
   public.im_offices o ON comps.customer_id = o.company_id
WHERE 
   comps.effective_date >= to_date(:start_date, 'YYYY-MM-DD')
   and comps.effective_date <= to_date(:end_date, 'YYYY-MM-DD')

ORDER BY o.company_id ASC
"

set report_def [list \
    group_by customer_id \
    header {
			$kontonummer
			$kontobezeichnung
			$kundennummer
			$anrede
			$firma
			$name
			$vorname
			$zusatz
			$land
			$strasse
			$plz
			$ort
			$ansprechpartner
			$telefon1
			$telefon2
			$telefax
			$email
			$bankleitzahl
			$bankkonto
			$bic
			$iban
			$bankbezeichnung
			$zahlungsziel
			$skonto
			$skonto_ziel
			$einzugsermaechtigung
    } \
    content {} \
    footer {} \
]




# Global header/footer
set header0 {"Kontonummer" "Kontobezeichnung" "Kundennummer" "Anrede" "Firma" "Name" "Vorname" "Zusatz" "Land" "Straße" "Postleitzahl" "Ort" "Ansprechpartner" "Telefon1" "Telefon2" "Telefax" "E-Mail" "Bankleitzahl" "Bankkonto" "BIC" "IBAN" "Bankbezeichnung" "Zahlungsziel" "Skonto %" "Skonto Ziel" "Einzugsermächtigung"}
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
		  <td class=form-label>Letzte Kto-Nr in BH</td>
		  <td class=form-widget>
		    <input type=textfield name=letzte_kto_nr value=$letzte_kto_nr>
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
      
    if {"" == $customer_id} {
	set customer_id 0
	set customer_name [lang::message::lookup "" intranet-reporting.No_customer "Undefined Customer"]

    }
#ETM: Berechnung kto-nummern (wenn letzte_kto_nr angegeben)
	 if {[expr $letzte_kto_nr+0] != 0} {
	 set kontonummer [expr $kontonummer + $letzte_kto_nr]
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
