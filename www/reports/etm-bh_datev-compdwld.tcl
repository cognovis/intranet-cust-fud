# /intranet-cust-fud/reports/etm-bh_AL-compdwld.tcl
#
# 
# 


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
    { cust_prov "customer_id" }
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set current_user_id [ad_maybe_redirect_for_registration]
set menu_label "etm-bh_datev-compdwld"

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





# ------------------------------------------------------------
# Constants
#



# Show all details for this report (no grouping)
set level_of_detail 1

##set agentauswahl {fud "FUD" pan "PAN" zis "ZIS"} 

set cust_prov_select {customer_id "Kunden" provider_id "Lieferanten"} 
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

if {"" != $letzte_kto_nr} { 
    set auto_kto_nr "ROW_NUMBER () over (order by o.company_id)"
} else { set auto_kto_nr "Null" }

# Page Settings

#set page_title "Neue Kunden: 1. Rg. zwischen $start_date und $end_date"
set page_title ""
set context_bar [im_context_bar $page_title]
set context ""

set help_text "
<strong>Firmen innerhalb start-end nach Datum der ersten Rechnung:<br>
<nobr>ACHTUNG: Format ist UTF-8 ...wichtig fuer Weiterverarbeitung in BH-Progs...</strong></nobr>
<br><br>
"


#set cost_type ""
#set cust_prov_incost ""


#if { "" == $cust_prov_incost } { 
#							set cust_prov_incost "c.customer_id"
#							}

#if { "" == $cost_type } { 
#							set cost_type "'3700'"
#							}

 
if { $cust_prov == "customer_id" } {
							set cust_prov_incost "c.customer_id"
							set bh_acc "'10000000' + comps.company_id"
							set cost_type "'3700'"
							set page_title "Kunden-Export"
							set agent_where "\nand im_name_from_id(c.template_id) LIKE 'zis%'"
	}	elseif { $cust_prov == "provider_id" } {
							set cust_prov_incost "c.provider_id"
							set bh_acc "'60000000' + comps.company_id"
							set cost_type "'3704'"
							set page_title "Lieferanten-Export"
							set agent_where ""
				 } else {}

if { ![empty_string_p $agent_where] } {
    set agent_where "$agent_where"
}

#if { "" == $cust_prov_select  } {
#							set cust_prov "customer_id"
#						}

### ------------------------------------------------------------
### Conditional SQL Where-Clause

### ETM: setzen der agentur
##	if { $agentauswahl == "fud" } {
##							set agent_where "AND c.cost_name LIKE 'I9%'"
##	}	elseif { $agent == "pan" } {
##							set agent_where "AND c.cost_name LIKE 'I3%'"
##	}	elseif { $agent == "zis" } {
##							set agent_where "AND c.cost_name LIKE 'IZ%'"
##	}  else { 			set agent_where ""
##	}

# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#

##set cust_prov "customer_id"
##set cost_type '3700'

#WEITERMACHEN: comps in inner_sql auf sowenig wie mgl felder beschraenken und danach grossabfrage in sql auch der comp-daten
#SELECT DISTINCT ON ($cust_prov_incost) 

set inner_sql "
SELECT DISTINCT ON ($cust_prov_incost) 
   $cust_prov_incost as company_id, 
   c.effective_date,
   c.payment_days,
   c.cost_name,
   CASE WHEN c.cost_type_id = '3700' AND c.cost_name LIKE 'I9%' THEN 'FUD'
	WHEN c.cost_type_id = '3700' AND c.cost_name LIKE 'I3%' THEN 'PAN'
	WHEN c.cost_type_id = '3700' AND c.cost_name LIKE 'IZ%' THEN 'ZIS'
	WHEN c.cost_type_id = '3704' AND c.cost_name LIKE 'B9%' THEN 'FUD'
	WHEN c.cost_type_id = '3704' AND c.cost_name LIKE 'B3%' THEN 'PAN'
	WHEN c.cost_type_id = '3704' AND c.cost_name LIKE 'BZ%' THEN 'ZIS'
	WHEN c.cost_type_id = '3704' AND im_name_from_id(c.cost_type_id) LIKE 'fud%' THEN 'FUD'
	WHEN c.cost_type_id = '3704' AND im_name_from_id(c.cost_type_id) LIKE 'pan%' THEN 'PAN'
	WHEN c.cost_type_id = '3704' AND im_name_from_id(c.cost_type_id) LIKE 'zis%' THEN 'ZIS'
   end as agent,
   i.payment_method_id,
   i.company_contact_id,
   pn.first_names,
   pn.last_name,
   pt.email as email,
   comp.main_office_id,
   comp.company_type_id,
   comp.vat_number,
   comp.bank_acc_owner,
   comp.bank_sort_code,
   comp.bank_accno,
   comp.bank_swift,
   comp.bank_iban,
   comp.bank,
   comp.payment_email
   FROM im_costs c, im_companies comp, im_invoices i, parties pt, persons pn
   WHERE  $cust_prov_incost = comp.company_id 
	  AND c.cost_type_id = $cost_type 
	  AND i.company_contact_id = pt.party_id
	  AND i.company_contact_id = pn.person_id
	  AND c.cost_id = i.invoice_id
          $agent_where
   GROUP BY $cust_prov_incost, c.effective_date,c.payment_days,c.cost_type_id, c.cost_name,i.payment_method_id,comp.main_office_id,comp.company_type_id, comp.main_office_id,comp.bank_sort_code, comp.bank_accno,comp.bank_acc_owner,comp.bank_swift,comp.bank_iban,comp.vat_number, comp.bank,comp.payment_email,i.company_contact_id,pn.first_names,pn.last_name,pt.email
   ORDER BY $cust_prov_incost, c.effective_date
"

set sql "
SELECT DISTINCT ON  (o.company_id) 

  $bh_acc as kontonummer,
  comps.agent,
  comps.company_id as kundennummer,
  comps.company_type_id as company_type,
  NULL as anrede,
  case when comps.company_type_id = '11000010' then NULL 
			else  im_name_from_id(comps.company_id) 
			end as firma,
  case when comps.company_type_id = '11000010' then comps.last_name 
			else NULL 
			end as name,
  case when comps.company_type_id = '11000010' then comps.first_names 
			else NULL 
			end as vorname,
  NULL as zusatz,
  upper(o.address_country_code) as country_code,
   CASE WHEN comps.bank_iban is not NULL then  substring(comps.bank_iban from 1 for 2)
	ELSE upper(o.address_country_code)  end as bank_cc,
  o.address_line1 as strasse,
  o.address_postal_code as plz,
  o.address_city as ort,
  im_name_from_id(comps.company_contact_id) as ansprechpartner,
  o.phone as telefon1,
  NULL as telefon2,
  o.fax as telefax,
  comps.email as email,
  comps.vat_number as vat_id,
  substring(comps.vat_number,3) as vat_id_ohne_cc,
  NULL as tax_id,
  comps.payment_method_id,
  comps.bank,
  comps.bank_acc_owner as kontoinhaber,
  comps.bank_sort_code as bankleitzahl,
  comps.bank_accno as bankkonto,
  comps.bank_swift as bic,
  comps.bank_iban as iban,
  comps.bank as bankbezeichnung,
  comps.payment_email as paym_email,
  CASE 
	WHEN comps.payment_days = 30 THEN '30'	
	ELSE '10'
  END as zahlungsziel,
  '0,00' as skonto,
  NULL as skonto_ziel,
  NULL as einzugsermaechtigung
FROM 
  ($inner_sql) as comps
  LEFT OUTER JOIN 
   im_offices o ON comps.company_id = o.company_id
  	
WHERE 
   comps.effective_date >= to_date(:start_date, 'YYYY-MM-DD')
   and comps.effective_date <= to_date(:end_date, 'YYYY-MM-DD')
   
ORDER BY o.company_id ASC
"

set report_def [list \
    group_by kundennummer \
    header {			
			$agent		
			$kontonummer
			$erloeskonto
			$aufwandkonto
			$adresstyp
			$anrede			
			$name
			$vorname
			$firma
			$ansprechpartner
			$email
			$country_code
			$vat_id_ohne_cc
			$tax_id
			$strasse
			$plz
			$ort
			$country_code
			$bank_cc
			$bank
			$bankkonto
			$kontoinhaber
			$bankleitzahl
			$bic
			"<nobr>$iban</nobr>"
			$paym_email
			$zahlungstraeger
    } \
    content {} \
    footer {} \
]




# Global header/footer
set header0 { "Agentur" "Personenkontonummer" "Erloeskonto" "Aufwandskonto" "Adresstyp" "Anrede" "Nachname" "Vorname" "Unternehmensname" "Ansprechpartner" "Kontakt-Email" "Laenderkennung nach ISO-Code fuer USt-ID" "USt-ID ohne Laenderkennung" "Steuernummer" "Adresse" "Postleitzahl" "Ort" "Land" "Laenderkennung nach ISO-Code für Bankverbindung" "Bankname" "Kontonummer" "Kontoinhaber" "BLZ" "BIC" "IBAN" "Zahlungs-E-Mail" "Zahlungstraeger"}
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
		<table border=0 cellspacing=1 cellpadding=1>
		<tr>
		  <td class=form-label>Kunde o. Lieferant</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 cust_prov $cust_prov_select $cust_prov]
		  </td>
		</tr>
	<!--	  	
		 <tr>
		  <td class=form-label>Letzte Kto-Nr in BH</td>
		  <td class=form-widget>
		    <input type=textfield name=letzte_kto_nr value=$letzte_kto_nr>
		  </td>
		</tr>
	-->
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
      

#ETM: Berechnung kto-nummern (wenn letzte_kto_nr angegeben)
	 if {[expr $letzte_kto_nr+0] != 0} {
	 set kontonummer [expr $kontonummer + $letzte_kto_nr]
	 }
	
		


if {"11000011" == $company_type} {
			set adresstyp "2"
			set aufwandkonto ""
	 } elseif {"11000010" == $company_type} {
			set adresstyp "1"
			set aufwandkonto ""
	 } elseif {"provider_id" == $cust_prov} {
			set adresstyp "2"
			set aufwandkonto ""
    } else {
			   set erloeskonto ""
			   set adresstyp ""
				set aufwandkonto ""
			 }


set erloeskonto $country_code$adresstyp

if {"" != $iban} {
		set iban_geprueft "1"
		} else {
				set iban_geprueft ""
				}

if {"" != $paym_email || "11000334" == $payment_method_id } {
			set zahlungstraeger "9"
			} else {
					set zahlungstraeger ""
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
