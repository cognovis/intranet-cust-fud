# /packages/intranet-cust-fud/www/reports/etm-bh-FLBillSum.tcl
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
    { level_of_detail:integer 3 }
    { agent "all" }
    { output_format "html" }
    { number_locale "" }
    { customer_id:integer 0}
    { provider_id:integer 0 }
    { effective_or_creation_date "" }
    { incl_paid "open_only" }
    { pmfl:integer 0}
}

# ------------------------------------------------------------
# Security

# Label: Provides the security context for this report
# because it identifies unquely the report's Menu and
# its permissions.
set current_user_id [ad_maybe_redirect_for_registration]
#set menu_label "etm-bh_FLBillSum"
#set menu_label "etm-bh_transferExp"
# label von etm-pmfl-openPOs da kein eigener Menue-Eintrag, sondern als Link auf der Seite openPOs
set menu_label "etm-pmfl-openPOs"

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
#set pmfl :current_user_id

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
set this_url [export_vars -base "/intranet-cust-fud/reports/etm-bh_FLBillSum" {start_date end_date} ]
set openpo_url "/intranet-cust-fud/reports/etm-pmfl-openPOs?show_bills=0&provider_id="

# Deal with invoices related to multiple projects
im_invoices_check_for_multi_project_invoices

# Level
set levels {2 "nur FLRg" 3 "FL-Rg+Auftraege"} 
# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }
# ------------------------------------------------------------
# Constants
#



# Show all details for this report (no grouping)
#set level_of_detail 1

# ETM: agent und VLL oder FLL
set agentauswahl {all "Alle" fud_iban "FUD IBAN" fud_rest "FUD Rest" fud_alle "FUD Alle" pan_iban "PAN IBAN" pan_rest "PAN Rest" pan_alle "PAN Alle" zis_iban "ZIS IBAN" zis_rest "ZIS Rest" zis_alle "ZIS Alle" } 

# nach Rg.Datum oder nach Eingabedatum
set effective_or_creation_date_auswahl {creation "Eingangs-Datum" effective "Rg-Datum"} 

# bezahle Rg (nicht) anzeigen
set incl_paid_auswahl {incl_paid "inkl bezahlt" open_only "nur offene Rg.en"} 


# Get the list of everybody who once created POs or Bills
#set pmfl_options [db_list_of_lists pmfl "
#    select * from (
#	select
#		im_name_from_id(user_id) as user_name ,
#		user_id
#	from
#		users_active u,
#		(select member_id 
#		from group_distinct_member_map m 
#		where group_id = '27888') m
#	where
#		u.user_id = m.member_id
#   ) t
#   order by user_name
#"]
#set pmfl_options [linsert $pmfl_options 0 [list "" 0]]






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

set page_title "FLer Rgen"
set context_bar [im_context_bar $page_title]
set context ""

set help_text "
<strong>FLer Rgen<br><br>

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
db_1row next_date "
select
	to_char(sysdate::date  +1::integer, 'YYYY') as next_year,
	to_char(sysdate::date  +1::integer, 'MM') as next_month,
	to_char(sysdate::date  +1::integer, 'DD') as next_day
from dual
"


if {"" == $start_date} { 
	if { "21" <= $todays_day && $todays_day <= "31" } {
	      set start_date "$todays_year-$todays_month-21"
	  } elseif { "01" <= $todays_day && $todays_day <= "05" && "01" != $todays_month} {
	      set start_date "$todays_year-$last_month-21"
	  } elseif { "01" <= $todays_day && $todays_day <= "05" && "01" == $todays_month} {
	      set start_date "$last_year-12-21"
	  } elseif { "06" <= $todays_day && $todays_day <= "20" } {
	      set start_date "$todays_year-$todays_month-06"
	  }
}


if {"" == $end_date} { 
	if { 21 <= $todays_day && $todays_day <= 31 && 12 != $todays_month} {
	      set end_date "$todays_year-$next_month-05"
	  } elseif { 21 <= $todays_day && $todays_day <= 31 && 12 == $todays_month} {
	      set end_date "$next_year-01-05"
	  } elseif { 01 <= $todays_day && $todays_day <= 05 } {
	      set end_date "$todays_year-$todays_month-05"
	  } elseif { 06 <= $todays_day && $todays_day <= 20 } {
	      set end_date "$todays_year-$todays_month-20"
	  }
}


# FLer open-bills url
set comp_bills "/intranet-cost/list?order_by=Name&how_many=-1&view_name=cost_list&view_mode=view&start_date=$start_date&end_date=$end_date&cost_status_id=3804&cost_type_id=3704&company_id="

#set comp_bills_short "/intranet-cost/list?order_by=Name&how_many=-1&view_name=cost_list&view_mode=view&cost_status_id=3804&cost_type_id=3704&company_id="
#set comp_bills_short "/intranet-cust-fud/reports/etm_invoice_list?order_by=Name&how_many=-1&view_name=cost_list&view_mode=view&cost_status_id=3804&cost_type_id=3704&company_id="

set comp_bills_short "/intranet-cust-fud/reports/etm_invoice_list?order_by=Document+%23&how_many=-1&view_name=etm_invoice_list&cost_status_id=&cost_type_id=3704&company_id="


set comp_pos "/intranet-cost/list?order_by=Name&how_many=-1&view_name=cost_list&view_mode=view&start_date=$start_date&end_date=$end_date&cost_type_id=3704&company_id="
# Provider setzen
set provider_where ""
if {"" != $provider_id && 0 != $provider_id} {
    set provider_where "and c.provider_id = :provider_id\n"
}

# PMFLer setzen
set pmfl_where ""
if {"" != $pmfl && 0 != $pmfl} {
    set pmfl_where "and acs.creation_user = :pmfl\n"
}

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }



# index

#set paym_index "ROW_NUMBER () over"

##TODO
# ETM: setzen der agentur und bh-korr-konten
	
set agent_where ""	
set kontokorr_case ""
set iban_where ""
set kontokorr ""



						

set nointernals_where "\nAND comp.company_type_id not in (53,11000000)"

		    if { $agent == "all" } {
							
							set page_title "All transfers"
							set agent_where ""
							set iban_where ""	
	}	elseif { $agent == "fud_iban" } {
							
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
	

# voreinstellung auf current_user
#set pmfl_where "AND acs.creation_user = :current_user_id"

if { $effective_or_creation_date == "effective" } {
		set effective_or_creation_date "c.effective_date"	
	} else {
	set effective_or_creation_date "c.creation_date"	
	}

if { $incl_paid == "incl_paid" } {
		set paid_where ""	
	} else {
		set paid_where "AND c.cost_status_id != '3810'"	
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

if { ![empty_string_p $provider_where] } {
    set provider_where "$provider_where"
}

if { ![empty_string_p $pmfl_where] } {
    set pmfl_where "$pmfl_where"
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
	to_char((round(c.amount::numeric,2)), '9999999D99')  as betrag,
	c.amount,
	c.currency as waehrung,
	c.cost_status_id,
	im_name_from_id(c.cost_status_id) as coststatus,
	c.cost_name,
	c.cost_id,
	im_name_from_id(c.cost_status_id) as status,
	comp.company_id + 60000000 as prov_konto,
	case  when c.note is null then 'FL-RG Name FEHLT' else trim(from c.note) end as rgfl,
	c.note,
	--comp.company_id || c.note as note_id_base,
	--regexp_replace(comp.company_id || to_char(c.effective_date, 'DDMMY') || c.note, \'\[\^0-9\]+\', '', 'g') as note_id,
	--(comp.company_id || to_char(c.effective_date, 'DDMMYY') || substring((regexp_replace(c.note, \'\[\^0-9\]+\', '', 'g')) from char_length(regexp_replace(c.note, \'\[\^0-9\]+\', '', 'g')) -1)) as note_id,
	case when c.note is null then comp.company_id || to_char(c.effective_date, 'DDMMY') ||'0' 
	else (comp.company_id || to_char(c.effective_date, 'DDMMY') || substring((regexp_replace(c.note, \'\[\^0-9\]+\', '', 'g')) from char_length(regexp_replace(c.note, \'\[\^0-9\]+\', '', 'g')) -1)) end as note_id,
	im_name_from_id(comp.company_id),	
	comp.company_id,
	c.cost_name as auftrag,
	c.cost_id,
	$kontokorr_case
	c.template_id,
	case when im_name_from_id(c.template_id) like 'fud%' then 'FUD'
	     when im_name_from_id(c.template_id) like 'pan%' then 'PAN'
	     when im_name_from_id(c.template_id) like 'zis%' then 'ZIS'
	  end as agentur,
	i.payment_method_id,
	case when i.payment_method_id = '800' then im_name_from_id(comp.default_payment_method_id) else im_name_from_id(i.payment_method_id) end as payment_method,
	comp.payment_email,
	comp.bank,
	comp.bank_acc_owner,
	acs.creation_date,
	im_name_from_id(acs.creation_user) as creation_user,
	acs.last_modified,
	c.effective_date,
	to_char(c.effective_date, 'YYYY.MM.DD') as rg_datum,
	to_char(c.effective_date, 'YYYY-MM-DD') as eff_datum,	
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
	$iban_where
	$agent_where
	$paid_where
	$provider_where
	$pmfl_where
	order by comp.company_name, note_id
"





	set report_def [list \
		 group_by company_id \
		 header {
				"\#colspan=4 <a href=$company_url$company_id>$company_name</a><br> 
				$bankinfo
				
				" 
				
		    } \
			content [list \
			    group_by note_id \
			    header { } \
			    content [list \
				header {
				""
				""
				"<a href=$comp_bills_short$company_id&start_date=$rg_datum&end_date=$rg_datum>$rg_datum</a><br>Eintrag: $eintrag"
				$agentur
				"<a href=$invoice_url$cost_id>$auftrag</a>"						
				$betrag
				$waehrung	
				$creation_user
				$status
			 } \
			 content {} \
		] \
		 footer {
    		""
		""
		"" 
		""
		"<b>Total <i>$note</i></b>"  
 
		"<nobr><i><b>$betrag_subtotal</b></i></nobr>" 
		$waehrung <br> 
		} \
    ] \
    footer {$openPOs_link_footer } \
]
#



# Global header/footer
set header0 {"Company" "RgFL" "Rg-Datum" "Agentur" "Auftrag" "Betrag" "Waehrung" "angelegt von" "Status" }

# Global Footer Line
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
		  <td class=form-label>Eingetragen von:</td>
		  <td class=form-widget>
		    [im_user_select -include_empty_p 1 -include_empty_name "All" -group_id "27888" pmfl $pmfl ]
		  </td>
		  <td class=form-label>Datum filtern nach</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 effective_or_creation_date $effective_or_creation_date_auswahl $effective_or_creation_date]
		  </td>
		</tr>

		<tr>
		  <td class=form-label>Start Date</td>
		  <td class=form-widget>
		    <input type=textfield name=start_date value=$start_date>
		  </td>

		  <td class=form-label>End Date</td>
		  <td class=form-widget>
		    <input type=textfield name=end_date value=$end_date>
		  </td>
		</tr>

		
		<tr>
		  <td class=form-label>Bezahlte anzeigen?</td>
		  <td class=form-widget>
		    [im_select -translate_p 0 incl_paid $incl_paid_auswahl $incl_paid]
		  </td>

		  <td>Level of<br>Details</td>
		  <td>
		    [im_select -translate_p 0 level_of_detail $levels $level_of_detail]
		  </td>
		</tr>
		<tr>		
		  <td class=form-label>Freelancer</td>
		  <td class=form-widget>
		    [im_company_select provider_id $provider_id "" "Provider"]
		  </td>
		</tr>



<!--
                <tr>
                  <td class=form-label>Format</td>
                  <td class=form-widget>
                    [im_report_output_format_select output_format "" $output_format]
                  </td>

                  <td class=form-label><nobr>Number Format</nobr></td>
                  <td class=form-widget>
                    [im_report_number_locale_select number_locale $number_locale]
                  </td>
                </tr>
-->

		<tr>
		  <td class=form-label></td>
		  <td class=form-widget><input type=submit value=Submit></td>
				  <td></td>
		  <td>
		    <a href=$openpo_url> zurueck zur Uebersicht offener Auftraege</a>
		  </td>
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



# *********************************************************
# Counters 

set betrag_subtotal_counter [list \
        pretty_name "Invoice Amount" \
        var betrag_subtotal \
        reset \$note_id \
        expr "\$amount+0" \
]

#
# Grand Total Counters
#
#set betrag_grand_total_counter [list \
#        pretty_name "Invoice Amount" \
#        var betrag_total \
#        reset 0 \
#        expr "\$amount+0" \
]

set counters [list \
	$betrag_subtotal_counter \
]
#aus counters entfernt	$betrag_grand_total_counter \


# Set the values to 0 as default
#set betrag_total 0






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

set counter 0
set class ""

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
if {"" != $empfaenger} { regsub -all {[^a-zA-Z0-9[:space:][-]]}  $empfaenger "_" empfaenger}

if {"" != $rgfl} { regsub -all {[ä]}  $rgfl "ae" rgfl}
if {"" != $rgfl} { regsub -all {[Ä]}  $rgfl "Ae" rgfl}
if {"" != $rgfl} { regsub -all {[ö]}  $rgfl "oe" rgfl}
if {"" != $rgfl} { regsub -all {[Ö]}  $rgfl "Oe" rgfl}
if {"" != $rgfl} { regsub -all {[ü]}  $rgfl "ue" rgfl}
if {"" != $rgfl} { regsub -all {[Ü]}  $rgfl "Ue" rgfl}
if {"" != $rgfl} { regsub -all {[^a-zA-Z0-9[:space:]]}  $rgfl "_" rgfl}




#if {"" != $note_id_base} { regsub -all {[^0-9]}  $note_id_base "" note_id}


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

## check ob nachtraeglich veraendert
#    if {$creation_date ne $last_modified} {
#	set changed "wurde am <font color=red>$last_modified_formatted</font> nachtraeglich geaendert"
#	} else { set changed ""}

# auf status 'bezahlt' pruefen
    if { 3810 == $cost_status_id } {
	set betrag "<font color=red>$betrag</font>"
	set note "<font color=red>$note (BEZAHLT)</font>"
	set status "<font color=red>$status</font>"
	}

## fehlender FL-Rg-Name
#    if { "" == $note } {
#	set verwendungszweck_1 "<font color=red>$verwendungszweck_1</font>"} 
#    if { "" == $note } {
#	set rgfl "<font color=red>$rgfl</font>"} 


# bankinfo ein/ausblenden

     if { 3 == $level_of_detail } {
	set bankinfo "		Empfaenger: $empfaenger <br>
				<a> $payment_method</a><br>
				<a> $bank</a><br>
				<a> $iban_accno</a><br>
				<a> $bic_sortcode</a><br>
				<a> $payment_email</a><br>
			"
	set openPOs_link_footer "\#colspan=9 *******************************************************<a href=$openpo_url$company_id> offene Auftraege anzeigen fuer $company_name</a> *********************************************************<br><br>"	
	} else { 
		set bankinfo "" 
		set openPOs_link_footer ""		
		}


     if {"" == $note } {
	set note "<font color=red>RgNr fehlt!!!!!</font>"}

# anpassen von datum fuer bill-link
########## ab tcl 8.5 da format flag nicht unterstuetzt in 8.4 ###########
#	set aux_dateformat {%Y-%m-%d}
#	set eff_datum [	clock scan $eff_datum -format %Y-%m-%d ]
#	set aux_startdate [clock add $eff_datum -1 day ]
#	set aux_startdate [clock format $aux_startdate -format %Y-%m-%d]
#	set aux_enddate [clock add $eff_datum 1 day ]
#	set aux_enddate [clock format $aux_enddate -format %Y-%m-%d]	
############################################################################




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

	incr counter

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
