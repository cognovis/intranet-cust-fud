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
    { agent "fud_alle" }
    { output_format "html" }
    { number_locale "" }
    { customer_id:integer 0}
    { effective_or_creation_date "" }
    { incl_paid "" }
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set current_user_id [ad_maybe_redirect_for_registration]
set menu_label "etm-bh_transferExp"

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
set this_url [export_vars -base "/intranet-cust-fud/reports/etm-bh_transferExp" {start_date end_date} ]


# Deal with invoices related to multiple projects
im_invoices_check_for_multi_project_invoices


# ------------------------------------------------------------
# Constants
#



# Show all details for this report (no grouping)
set level_of_detail 1

# ETM: agent und VLL oder FLL
set agentauswahl {fud_iban "FUD IBAN" fud_rest "FUD Rest" fud_alle "FUD Alle" pan_iban "PAN IBAN" pan_rest "PAN Rest" pan_alle "PAN Alle" zis_iban "ZIS IBAN" zis_rest "ZIS Rest" zis_alle "ZIS Alle" } 

# nach Rg.Datum oder nach Eingabedatum
set effective_or_creation_date_auswahl {creation "Eingangs-Datum" effective "Rg-Datum"} 

# bezahle Rg (nicht) anzeigen
set incl_paid_auswahl {incl_paid "inkl bezahlt&ohne RgName" open_only "nur offene mit RgName"} 


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
<strong>TransferExport<br><br>

"




# ------------------------------------------------------------
# Set the defaults

set days_in_past 0

db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month,
	to_char(sysdate::date - :days_in_past::integer, 'DD') as todays_day
from dual
"
db_1row last_date "
select
	to_char(sysdate::date  -1::integer, 'YYYY') as last_year,
	to_char(sysdate::date  -1::integer, 'MM') as last_month,
	to_char(sysdate::date  -1::integer, 'DD') as last_day
from dual
"



if {"" == $start_date} { 
	if { 21 <= $todays_day <= 31 } {
	      set start_date "$todays_year-$todays_month-06"
	  } elseif { 01 <= $todays_day <= 05 && 01 != $todays_month} {
	      set start_date "$todays_year-$last_month-06"
	  } elseif { 01 <= $todays_day <= 05 && 01 == $todays_month} {
	      set start_date "$last_year-12-06"
	  } elseif { 06 <= $todays_day <= 20 } {
	      set start_date "$todays_year-$last_month-21"
	  }
}


if {"" == $end_date} { 
	if { 21 <= $todays_day <= 31 } {
	      set end_date "$todays_year-$todays_month-20"
	  } elseif { 01 <= $todays_day <= 05 } {
	      set end_date "$todays_year-$last_month-20"
	  } elseif { 06 <= $todays_day <= 20 } {
	      set end_date "$todays_year-$last_month-05"
	  }
}


# index

#set paym_index "ROW_NUMBER () over"

##TODO
# ETM: setzen der agentur und bh-korr-konten
	
set agent_where ""	
set kontokorr_case ""
set iban_where ""
set kontokorr ""

#          if {[regexp {[fud_*]$} $agent]} {
#		set kontokorr_case " 
#		   case when im_name_from_id(c.template_id) like 'fud%' and comp.bank_iban is not NULL then 'FUD-DB'
#			when im_name_from_id(c.template_id) like 'fud%' and comp.bank ~ '(P|p)ay(P|p)al' then 'FUD-PP'
#			when im_name_from_id(c.template_id) like 'fud%' and (comp.bank like '%krill' or comp.bank like '%bookers') then 'FUD-MB'
#		      end as kontokorr,
#			"						
#		set agent_where "AND im_name_from_id(c.template_id) LIKE 'fud%'"			
#   }  elseif {[regexp {[pan_*]$} $agent]}  {
#		set kontokorr_case " 
#		   case when im_name_from_id(c.template_id) like 'pan%' and comp.bank_iban is not NULL then 'PAN-DB'
#		     when im_name_from_id(c.template_id) like 'pan%' and comp.bank ~ '(P|p)ay(P|p)al' then 'PAN-PP'
#		     when im_name_from_id(c.template_id) like 'pan%' and (comp.bank like '%krill' or comp.bank like '%bookers') then 'PAN-MB'
#		   end as kontokorr,
#		"						
#		set agent_where "AND im_name_from_id(c.template_id) LIKE 'pan%'"	
#   } elseif {[regexp {[zis_*]$} $agent]}  {
#		set kontokorr_case " 
#		   case when im_name_from_id(c.template_id like 'zis%' and comp.bank_iban is not NULL then 'ZIS-CB'
#		     when im_name_from_id(c.template_id) like 'zis%' and comp.bank ~ '(P|p)ay(P|p)al' then 'ZIS-PP'
#		     when im_name_from_id(c.template_id) like 'zis%' and (comp.bank like '%krill' or comp.bank like '%bookers') then 'ZIS-MB'
#		   end as kontokorr,
#		"						
#		set agent_where "AND im_name_from_id(c.template_id) LIKE 'zis%'"	
#   } else {set kontokorr ""}


## iban, ohne_iban (rest) oder alle
#         if {[regexp {[*_iban]$} $agent]} {
#		set iban_where "AND comp.bank_iban is not NULL"					
#   } elseif {[regexp {[*_rest]$} $agent]} {
#		set iban_where "AND comp.bank_iban is NULL"	
##   } elseif {[regexp {[*_alle]$} $agent]} {
##		set iban_where ""				
# 
#  } else {}
		

						

set nointernals_where "\nAND comp.company_type_id not in (53,11000000)"

		    if { $agent == "fud_iban" } {
							
							set page_title "FUD IBAN transfers"
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'fud%'"
							set iban_where "AND comp.bank_iban is not NULL"	
	}	elseif { $agent == "fud_rest" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'fud%'"
							set iban_where "AND comp.bank_iban is NULL"							
							set page_title "FUD ohne IBAN" 
	}	elseif { $agent == "fud_alle" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'fud%'"
							set iban_where ""							
							set page_title "FUD ALLES" 	
	}	elseif { $agent == "pan_iban" } {
							
							set page_title "PAN IBAN transfers"
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'pan%'"
							set iban_where "AND comp.bank_iban is not NULL"	
	}	elseif { $agent == "pan_rest" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'pan%'"
							set iban_where "AND comp.bank_iban is NULL"							
							set page_title "PAN ohne IBAN"
	}	elseif { $agent == "pan_alle" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'pan%'"
							set iban_where ""							
							set page_title "PAN ALLES" 
	}	elseif { $agent == "zis_iban" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'zis%'"
							set iban_where "AND comp.bank_iban is not NULL"								
							set page_title "ZIS IBAN transfers"
	}	elseif { $agent == "zis_rest" } {
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'zis%'"
							set iban_where "AND comp.bank_iban is NULL"							
							set page_title "ZIS Rest transfers"
	}	elseif { $agent == "zis_alle" } {
							
							set agent_where "AND im_name_from_id(c.template_id) LIKE 'zis%'"
							set iban_where ""
							set page_title "ZIS ALLES" 	
	}	else {}
	




if { $effective_or_creation_date == "effective" } {
		set effective_or_creation_date "c.effective_date"	
	} else {
	set effective_or_creation_date "c.creation_date"	
	}

if { $incl_paid == "incl_paid" } {
		set paid_where ""	
	} else {
		set paid_where "AND c.cost_status_id != '3810'\nAND c.note is not null"	
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



if { ![empty_string_p $agent_where] } {
    set agent_where "$agent_where"
}

#if { ![empty_string_p $buchungstextpre] } {
#	 set buchungstextpre "$buchungstextpre"
#}

if { ![empty_string_p $iban_where] } {
    set iban_where "$iban_where"
}

if { ![empty_string_p $paid_where] } {
    set paid_where "$paid_where"
}
# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#



set sql "

select 	row_number() over (order by i.payment_method_id, comp.company_name) as paym_index,
	substr(comp.company_name,0,27) as company_name,
	comp.bank_iban,
	case when comp.bank_acc_owner is not null then comp.bank_acc_owner else comp.company_name end as empfaenger,
	case when comp.bank_iban is not null then replace(comp.bank_iban,' ','')
	     when comp.bank_accno is not null then replace(comp.bank_accno,' ','')
	     else '' end as iban_accno,
	case when comp.bank_swift is not null AND length(replace(comp.bank_swift,' ','')) = 11 then replace(comp.bank_swift,' ','')
	     when comp.bank_swift is not null AND length(replace(comp.bank_swift,' ','')) = 8 then replace(comp.bank_swift,' ','') || 'XXX'
	     when comp.bank_swift is not null AND (length(replace(comp.bank_swift,' ','')) != 8 OR (length(replace(comp.bank_swift,' ',''))) != 11) then 'Format falsch ' || comp.bank_swift
	     when comp.bank_sort_code is not null then replace(comp.bank_sort_code,' ','')
	     else '' end as bic_sortcode,
	case when c.currency != 'EUR' and c.vat is not null then 
	 to_char(round(((c.amount + (c.amount * c.vat/100)) * 
	  im_exchange_rate(c.effective_date::date, c.currency, 'EUR'))::numeric, 2), '9999999D99') 
	     when c.currency != 'EUR' and c.vat is null then 
	 to_char(round(((c.amount) * 
	  im_exchange_rate(c.effective_date::date, c.currency, 'EUR'))::numeric, 2), '9999999D99') 
	  else to_char((round(c.amount::numeric,2)), '9999999D99')
	  end as betrag,
	'EUR' as waehrung,
	c.cost_status_id,
	im_name_from_id(c.cost_status_id) as coststatus,
	c.cost_name,
	c.cost_id,
	im_name_from_id(c.cost_status_id) as status,
	comp.company_id + 60000000 as prov_konto,
	case  when c.note is null then 'FL-RG Name FEHLT' else trim(from c.note) end as rgfl,
	c.note,
	comp.company_id,
	case when length((trim(from c.note))) <= 23 then comp.company_id + 60000000 || ' ZA ' || trim(from c.note)  
	     when length((trim(from c.note))) > 23 then comp.company_id + 60000000 || ' ZA ' || substr((trim(from c.note)),0,23)
	     when c.note is null then 'FL-RG Name FEHLT'
	   end as verwendungszweck_1,
	case when length((trim(from c.note))) <= 23 then to_char(c.effective_date, 'YYYYMMDD')
	     when length((trim(from c.note))) > 23 then   substr(c.note, 24,14)|| ' ' || to_char(c.effective_date, 'YYYYMMDD')
	     when c.note is null then to_char(c.effective_date, 'YYYYMMDD')
	   end as verwendungszweck_2,
	c.cost_name as verwendungszweck_3,
	case when c.currency != 'EUR' then round(c.amount,2) || ' ' || c.currency else '' end as verwendungszweck_4,
	c.cost_id,
	case when c.currency != 'EUR' then c.currency end as fremdwhrg,
	$kontokorr_case
	c.template_id,
	i.payment_method_id,
	case when i.payment_method_id = '800' then im_name_from_id(comp.default_payment_method_id) else im_name_from_id(i.payment_method_id) end as payment_method,
	comp.payment_email,
	comp.bank,
	acs.creation_date,
	im_name_from_id(acs.creation_user) as creation_user,
	acs.last_modified,
	to_char(c.effective_date, 'YYYY.MM.DD') as rg_datum,
	to_char(acs.creation_date, 'YYYY.MM.DD') as eintrag
from	im_costs c ,
	im_invoices i,
	im_companies comp,
	acs_objects acs
where 	c.provider_id = comp.company_id
	AND c.cost_id = acs.object_id 
	AND c.cost_id = i.invoice_id
	and acs.creation_date >= to_date(:start_date, 'YYYY.MM.DD')
   	and acs.creation_date <= to_date(:end_date, 'YYYY.MM.DD')
	and c.cost_type_id = '3704'
	--and comp.bank is not null
	$iban_where
	$agent_where
	$paid_where
	order by i.payment_method_id, comp.company_name, c.note
"





	set report_def [list \
		 group_by customer_id \
		 header {
				$paym_index
				"<a href=$company_url$company_id>$empfaenger</a>"
				$iban_accno
				$bic_sortcode
				$betrag
				$waehrung	
				$prov_konto
				$verwendungszweck_1
				$verwendungszweck_2
				"<a href=$invoice_url$cost_id>$verwendungszweck_3</a>"
				$verwendungszweck_4
				$bank
				$payment_email
				$payment_method
				$rgfl
				$rg_datum
				$status
				$cost_id
				$creation_user
				$changed
				
		 } \
		 content {} \
		 footer {} \
	]




# Global header/footer
set header0 {"Pos" "Empfaengername" "Kontonummer/IBAN" "Bankleitzahl/BIC" "Betrag" "Waehrung" "Mandatsreferenz" "Verwendungszweck 1" "Verwendungszweck 2" "Verwendungszweck 3" "Verwendungszweck 4" "Bank" "Bezahl-Mail (PP/MB)" "Bezahlmethode" "RgFL" "Rg-Datum" "Status" "Cost_ID" "angelegt von" "nachtraeglich geaendert?" }
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
		  <td class=form-label>Datum filtern nach</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 effective_or_creation_date $effective_or_creation_date_auswahl $effective_or_creation_date]
		  </td>
		</tr>
		<tr>
		  <td class=form-label>Bezahlte anzeigen?</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 incl_paid $incl_paid_auswahl $incl_paid]
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
     
#	set buchungsbetrag_netto_pretty [im_report_format_number $betrag $output_format $number_locale]
#	set buchungsbetrag_steuer_pretty [im_report_format_number $betrag $output_format $number_locale]
#	set buchungsbetrag_brutto_pretty [im_report_format_number $betrag $output_format $number_locale]



# sonderzeichen-behandlung
if {"" != $empfaenger} { regsub -all {[ä]}  $empfaenger "ae" empfaenger}
if {"" != $empfaenger} { regsub -all {[Ä]}  $empfaenger "Ae" empfaenger}
if {"" != $empfaenger} { regsub -all {[ö]}  $empfaenger "oe" empfaenger}
if {"" != $empfaenger} { regsub -all {[Ö]}  $empfaenger "Oe" empfaenger}
if {"" != $empfaenger} { regsub -all {[ü]}  $empfaenger "ue" empfaenger}
if {"" != $empfaenger} { regsub -all {[Ü]}  $empfaenger "Ue" empfaenger}
if {"" != $empfaenger} { regsub -all {[^a-zA-Z0-9[:space:][-]]}  $empfaenger "" empfaenger}

if {"" != $rgfl} { regsub -all {[ä]}  $rgfl "ae" rgfl}
if {"" != $rgfl} { regsub -all {[Ä]}  $rgfl "Ae" rgfl}
if {"" != $rgfl} { regsub -all {[ö]}  $rgfl "oe" rgfl}
if {"" != $rgfl} { regsub -all {[Ö]}  $rgfl "Oe" rgfl}
if {"" != $rgfl} { regsub -all {[ü]}  $rgfl "ue" rgfl}
if {"" != $rgfl} { regsub -all {[Ü]}  $rgfl "Ue" rgfl}
if {"" != $rgfl} { regsub -all {[^a-zA-Z0-9[:space:]]}  $rgfl "" rgfl}

if {"" != $verwendungszweck_1} { regsub -all {[ä]}  $verwendungszweck_1 "ae" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[Ä]}  $verwendungszweck_1 "Ae" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[ö]}  $verwendungszweck_1 "oe" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[Ö]}  $verwendungszweck_1 "Oe" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[ü]}  $verwendungszweck_1 "ue" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[Ü]}  $verwendungszweck_1 "Ue" verwendungszweck_1}
if {"" != $verwendungszweck_1} { regsub -all {[^a-zA-Z0-9[:space:]]}  $verwendungszweck_1 "" verwendungszweck_1}

if {"" != $verwendungszweck_2} { regsub -all {[ä]}  $verwendungszweck_2 "ae" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[Ä]}  $verwendungszweck_2 "Ae" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[ö]}  $verwendungszweck_2 "oe" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[Ö]}  $verwendungszweck_2 "Oe" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[ü]}  $verwendungszweck_2 "ue" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[Ü]}  $verwendungszweck_2 "Ue" verwendungszweck_2}
if {"" != $verwendungszweck_2} { regsub -all {[^a-zA-Z0-9[:space:]]}  $verwendungszweck_2 "" verwendungszweck_2}

if {"" != $verwendungszweck_3} { regsub -all {[ä]}  $verwendungszweck_3 "ae" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[Ä]}  $verwendungszweck_3 "Ae" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[ö]}  $verwendungszweck_3 "oe" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[Ö]}  $verwendungszweck_3 "Oe" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[ü]}  $verwendungszweck_3 "ue" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[Ü]}  $verwendungszweck_3 "Ue" verwendungszweck_3}
if {"" != $verwendungszweck_3} { regsub -all {[^a-zA-Z0-9[:space:]]}  $verwendungszweck_3 "" verwendungszweck_3}


##set sonderzeichen_felder_list [list "empfaenger" "rgfl" "verwendungszweck_1" "verwendungszweck_2" "verwendungszweck_3" LAST]
#set sonderzeichen_felder_list [list verwendungszweck_1 empfaenger rgfl verwendungszweck_2 verwendungszweck_3 LAST]
##foreach i { verwendungszweck_1 empfaenger rgfl verwendungszweck_2 verwendungszweck_3}
#foreach i $sonderzeichen_felder_list {
#if {"" != $i} { regsub -all {[ä]}  $i "ae" i}
#if {"" != $i} { regsub -all {[Ä]}  $i "Ae" i}
#if {"" != $i} { regsub -all {[ö]}  $i "oe" i}
#if {"" != $i} { regsub -all {[Ö]}  $i "Oe" i}
#if {"" != $i} { regsub -all {[ü]}  $i "ue" i}
#if {"" != $i} { regsub -all {[Ü]}  $i "Ue" i}
#if {"" != $i} { regsub -all {[^a-zA-Z0-9[:space:]]}  $i "_" i}
#}


 
    if {"" == $customer_id} {
	set customer_id 0
	set customer_name [lang::message::lookup "" intranet-reporting.No_customer "Undefined Customer"]
   }

# check ob nachtraeglich veraendert
    if {$creation_date ne $last_modified} {
	set changed "wurde am <font color=red>$last_modified_formatted</font> nachtraeglich geaendert"
	} else { set changed ""}

# auf status 'bezahlt' pruefen
    if { 3810 == $cost_status_id } {
	set betrag "<font color=red>bezahlt: $betrag</font>"}

# fehlender FL-Rg-Name
    if { "" == $note } {
	set verwendungszweck_1 "<font color=red>$verwendungszweck_1</font>"} 
    if { "" == $note } {
	set rgfl "<font color=red>$rgfl</font>"} 


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
    -upvar_level 1ü


switch $output_format {
    html { ns_write "</table>\n[im_footer]\n" }
}
