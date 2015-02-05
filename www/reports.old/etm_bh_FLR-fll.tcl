# /packages/intranet-cust-fud/www/reports/etm_bh_FLR-fll-vll.tcl
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
	 { agent "zis_ford" }
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
set menu_label "etm_bh_FLR-fll"

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

# ETM: agent und VLL oder FLL
#set agentauswahl {fud_ford "FUD Fordg" fud_verb "FUD Verbkt" pan_ford "PAN Fordg" pan_verb "PAN Verbkt" zis_ford "ZIS Fordg" zis_verb "ZIS Verbkt"} 
#set agentauswahl {zis_ford "ZIS Fordg" zis_verb "ZIS Verbkt"} 
set agentauswahl {fud_ford "FUD Fordg" pan_ford "PAN Fordg" zis_ford "ZIS Fordg" } 
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

#set help_text "
#<strong>Forderungen oder Verbindlichkeiten innerhalb start-end nach Belegdatum<br><br>
#<table><nobr>
#<tr><td><nobr><strong>ZIS</strong></td><td><nobr><strong>Fremdleistungen</strong></td><td><nobr><strong>Standardkonten</strong></td></tr>
#<tr><td><nobr>ZIS: privat   | de 		-> 4400 </td><td><nobr>Projektaufwand	5201 </td><td><nobr>Werbung	6600</td></tr>
#<tr><td><nobr>ZIS: privat 	 | eu 		-> 4400 </td><td><nobr>Projektmanagement	5210 </td><td><nobr>Telefon	6805</td></tr>
#<tr><td><nobr>ZIS: privat 	 | noneu 	-> 4338 </td><td><nobr>Domainverwaltung	5901 </td><td><nobr>Telefax und Internet	6810</td></tr>
#<tr><td><nobr>ZIS: business | de 		-> 4400 </td><td><nobr>Virtuelles Office	5902 </td><td><nobr>Bürobedarf	6815</td></tr>
#<tr><td><nobr>ZIS: business | eu 		-> 4336 </td><td><nobr>Programmierung	5903 </td><td><nobr>Fortbildungskosten	6821</td></tr>
#<tr><td><nobr>ZIS: business | noneu 	-> 4338 </td><td><nobr>Verwaltung	5904 </td><td><nobr>Abschluss- und Prüfungskosten	6827</td></tr>
#<tr><td><nobr></td><td>Verwaltung System	5905 </td><td><nobr>Buchführungskosten	6830</td></tr>
#<tr><td><nobr></td><td>Betreuung Website	5907 </td><td><nobr>Mieten für Einrichtungen (bewegliche WG)	6835</td></tr>
#<tr><td><nobr></td><td></td><td><nobr>Nebenkosten Geldverkehr	6855</td></tr>
#</nobr>
#</table>
#"

set help_text "
<strong>Forderungen innerhalb start-end nach Belegdatum<br><br>
<table><nobr>
<tr><td><nobr><strong>Sachkonten ZIS</strong></td><td><nobr><strong>Sachkonten FUD/PAN</strong></td></tr>
<tr><td><nobr>ZIS: privat   | de 		-> 4400 </td><td><nobr>FUD: privat/business   | ch/non-ch 		-> 4000 </td></tr>
<tr><td><nobr>ZIS: privat 	 | eu 		-> 4400 </td><td></td></tr>
<tr><td><nobr>ZIS: privat 	 | noneu 	-> 4338 </td><td><nobr></td></tr>
<tr><td><nobr>ZIS: business | de 		-> 4400 </td><td><nobr></td></tr>
<tr><td><nobr>ZIS: business | eu 		-> 4336 </td><td><nobr></td></tr>
<tr><td><nobr>ZIS: business | noneu 	-> 4338 </td><td><nobr></td></tr>
<tr><td><nobr></td><td></td></tr>
<tr><td><nobr></td><td></td></tr>
<tr><td><nobr></td><td></td></tr>
</nobr>
</table>
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


# eu-laender
set eu "'AT','BE','BG','CY','CZ','DE','DK','EE','EL','ES','FI','FR','HR','HU','IE','IT','LT','LU','LV','MT','NL','PL','PT','RO','SE','SI','SK','UK'"
set noneu ""


## cost-centers
##525;"The Company"
##12368;"System Administration"
##526;"Administration"
##529;"Marketing"
##530;"Operations"
##12364;"Software Development"
##12388;"Project Management"
##304791;"ZIS"
##85004;"FUD"
##53182;"ProjMan"
##554725;"PAN"


# ETM: setzen der agentur und FLL/VLL
	
	set buchungstextpre ""
	set cust_or_prov ""
	set vatwert "0,0"

if {[regexp {[*_ford]$} $agent]} {
							set buchungstextpre "''"
							set buchungstextpost "''"
							set cust_or_prov "ci.customer_id"
							set cost_type "'3700'"
							set belegnummerauswahl "ci.cost_name"
							set pref_bhkto "10000000"
						}

if {[regexp {[*_verb]$} $agent]} {
							set buchungstextpre "''"
							set buchungstextpost "ci.cost_name"
							set cust_or_prov "ci.provider_id"
							set cost_type "'3704'"
							set belegnummerauswahl "ci.note"
							set pref_bhkto "60000000"
						}

##if {[regexp {[fud_*]$} $agent]} {
##							set buchungstextpre "'PA '"
##							set buchungstextpost "ci.cost_name"
##							set cust_or_prov "ci.provider_id"
##							set cost_type "'3704'"
##							set belegnummerauswahl "ci.note"
##						}

set nointernals_where "\nAND comp.company_type_id not in (53,11000000)"

if { $agent == "fud_ford" } {
							set agent_where "AND ci.cost_name LIKE 'I9%'"
							set page_title "FUD Forderungen"
	}	elseif { $agent == "fud_verb" } {
							set agent_where "AND im_name_from_id(ci.template_id) LIKE 'fud%'"
							set page_title "FUD Verbindlichkeiten" 
	}	elseif { $agent == "pan_ford" } {
							set agent_where "AND ci.cost_name LIKE 'I3%'"
							set page_title "PAN Forderungen"
	}	elseif { $agent == "pan_verb" } {
							set agent_where "AND im_name_from_id(ci.template_id) LIKE 'pan%'"
							set page_title "PAN Forderungen"
	}	elseif { $agent == "zis_ford" } {
							set agent_where "AND ci.cost_name LIKE 'IZ%'"
							set page_title "ZIS Forderungen"
	}	elseif { $agent == "zis_verb" } {
							set agent_where "AND im_name_from_id(ci.template_id) LIKE 'zis%'"
							set page_title "ZIS Verbindlichkeiten"
	} else {}
	




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

if { ![empty_string_p $buchungstextpre] } {
	 set buchungstextpre "$buchungstextpre"
}


# ------------------------------------------------------------
# Define the report - SQL, counters, headers and footers 
#


set cost_sql "
select 
		c.cost_name,
		case 	when im_name_from_id(c.template_id) LIKE 'zis_%' then 'ZIS'
			when im_name_from_id(c.template_id) LIKE 'fud_%' then 'FUD'
			when im_name_from_id(c.template_id) LIKE 'pan_%' then 'PAN'
			end as agent_templ,		
		c.cost_type_id,
		c.note,
		im_name_from_id(c.template_id) as template,
		c.template_id,
		im_name_from_id(c.customer_id) as customer,
		c.customer_id,
		im_name_from_id(c.provider_id) as provider,
		c.provider_id,
		c.effective_date,
		c.delivery_date,
		to_char(c.delivery_date, 'DD.MM.YYYY') as delivery_date_formatted,
		c.cost_center_id,
		c.vat,
		round(c.vat :: numeric, 0) as vat_formatted,
		c.amount buchungsbetrag_orig_net,
		c.currency,
		round((c.amount * 
	  im_exchange_rate(c.effective_date::date, c.currency, :default_currency)) :: numeric
	  , 2) as buchungsbetrag_netto,
		round((c.amount * im_exchange_rate(c.effective_date::date, c.currency, 'CHF')) :: numeric
	  , 2) as buchungsbetrag_netto_CHF,
		round(((c.amount * c.vat/100) * 
	  im_exchange_rate(c.effective_date::date, c.currency, :default_currency)) :: numeric
	  , 2) as buchungsbetrag_steuer,
		round(((c.amount + (c.amount * c.vat/100)) * 
	  im_exchange_rate(c.effective_date::date, c.currency, :default_currency)) :: numeric
	  , 2) as buchungsbetrag_brutto,
	  	acs.last_modified,
	  	acs.creation_date,
		to_date(to_char(acs.last_modified, 'YYYYMMDDHHmmss'),'YYYYMMDDHHmmss') - to_date(to_char(acs.creation_date, 'YYYYMMDDHHmmss'),'YYYYMMDDHHmmss') as changed_days,
	  	to_char(acs.last_modified, 'DD.MM.YYYY') as last_modified_formatted,
	  	to_char(acs.creation_date, 'DD.MM.YYYY') as creation_date_formatted		
	from im_costs c,
	     acs_objects acs
   where c.cost_type_id = $cost_type
	AND c.cost_id = acs.object_id
"

set sql "
select
	ci.*, 
	--ci.cost_name as belegnummer,
	$belegnummerauswahl as belegnummer,
	to_char(ci.effective_date, 'DD.MM.YYYY') as belegdatum,
	case when ci.cost_type_id = '3700' then im_name_from_id(ci.customer_id)
		  when ci.cost_type_id = '3704' then im_name_from_id(ci.provider_id)
	end as kundeoderlieferant,
	case 	when upper(o.address_country_code) in ($eu) then 'eu'
		when upper(o.address_country_code) not in ($eu) then 'noneu' 
	end as country_group,
	upper(o.address_country_code) as country_code,
	comp.company_type_id,
	im_name_from_id(comp.company_type_id) as company_type,
	comp.company_id,
	'Uebersetzung Textbearbeitung' as leistung,
	NULL as steuernr,
	NULL as empty,
	regexp_replace(comp.vat_number, '\[\^a-zA-Z0-9\]+', '', 'g') as vat_number,
	--NULL as kundenoderlieferantenkonto,
	$pref_bhkto + comp.company_id as bhkonto,
	ci.cost_center_id,
	im_name_from_id(ci.cost_center_id) as cost_center_name,
	$buchungstextpre || im_name_from_id($cust_or_prov) || ' ' || $buchungstextpost as buchungstext
from 
	im_companies comp,	
	im_offices o,	
	($cost_sql) ci
where
	comp.company_id = $cust_or_prov
	and comp.main_office_id = o.office_id
	and ci.effective_date >= to_date(:start_date, 'YYYY.MM.DD')
   	and ci.effective_date <= to_date(:end_date, 'YYYY.MM.DD')
	$agent_where
	$nointernals_where
order by ci.cost_name
"



			set report_def [list \
				 group_by customer_id \
				 header {
						$buchungsbetrag_netto_pretty
						$buchungsbetrag_steuer_pretty
						$buchungsbetrag_brutto_pretty
						$buchungsbetrag_orig_net_pretty
						$currency
						$vat_formatted	
						$country_code
						$leistung					
						$belegnummer	
						$belegdatum				
						$bhkonto
						$company_id
						$buchungstext
						$steuernr
						$vat_number
						$sachkonto
						$empty

						
				 } \
				 content {} \
				 footer {} \
			]




# Global header/footer
set header0 {"Betrag netto (EUR)" "Betrag USt (EUR)" "Betrag brutto (EUR)" "Orig. Betrag netto" "Orig. Whrg" "USt-Satz" "Land des Rechnungsempfaengers" "Erbrachte Leistung" "Rechnungsnummer" "Rechnungsdatum" "Kundenkonto" "Kunden-Nr" "Kundenname" "Steuernummer" "USt-ID" "Sachkonto" "Gegenkonto/Umsatzskonto" }
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



# original-betraege wenn nicht EUR
	if { "EUR" == $currency } {
		set buchungsbetrag_orig_net ""
		set buchungsbetrag_orig_net_pretty ""
		set currency ""
	} else { set buchungsbetrag_orig_net_pretty [im_report_format_number $buchungsbetrag_orig_net $output_format $number_locale] }

     
	set buchungsbetrag_netto_pretty [im_report_format_number $buchungsbetrag_netto $output_format $number_locale]
	set buchungsbetrag_steuer_pretty [im_report_format_number $buchungsbetrag_steuer $output_format $number_locale]
	set buchungsbetrag_brutto_pretty [im_report_format_number $buchungsbetrag_brutto $output_format $number_locale]

	
 
    if {"" == $customer_id} {
	set customer_id 0
	set customer_name [lang::message::lookup "" intranet-reporting.No_customer "Undefined Customer"]
   }

# check ob nachtraeglich veraendert
    if {$creation_date ne $last_modified} {
	set changed "wurde am <font color=red>$last_modified_formatted</font> nachtraeglich geaendert"
	} else { set changed ""}

# check ob bei sonderkonten rg-name auch in notiz ist  
	if {[regexp {[*_ad_bill*]$} $template] && "" == $note } {  
			set belegnummerauswahl $cost_name
			} 

# eingangsdatum bei VLL als delivery_datum oder leer bei FLL 
	if { "3704" == $cost_type_id && "" == $delivery_date } {
		set eingangsdatum $creation_date_formatted 
	   } elseif { "3704" == $cost_type_id && "" != $delivery_date } {
		set eingangsdatum $delivery_date_formatted
	   } else { set eingangsdatum ""}




# zis erloeskonten nach kundentyp
# 57-> Customer (sollte eigentlich nicht vergeben sein!!!)
# 11000010 -> "Private Customer"
# 11000011 -> "Business Customer"
# 53 -> "Internal"
# 56 -> "Provider"
# 58 -> "Freelance Provider"

# --------ZIS-----------------------|-------Fremdleistungen----------|-----	Standardkonten--------------|
# ZIS: privat   | de 		-> 4400	| Projektaufwand 5201 				| 	Werbung 6600
# ZIS: privat 	 | eu 		-> 4400	| Projektmanagement 5210 			|	Telefon 6805
# ZIS: privat 	 | noneu 	-> 4338	| Domainverwaltung 5901 			|	Telefax und Internet 6810
# ZIS: business | de 		-> 4400	| Virtuelles Office 5902 			|	Bürobedarf 6815
# ZIS: business | eu 		-> 4336
# ZIS: business | noneu 	-> 4338




# ZIS-Konten
if { "ZIS" == $agent_templ } { 
		if { "11000010" == $company_type_id && "eu" == $country_group } {
				set sachkonto "4400" 
			} elseif { "11000010" == $company_type_id && "noneu" == $country_group } {
				set sachkonto "4338" 
			} elseif { "11000011" == $company_type_id && "eu" == $country_group && "DE" != $country_code } {
				set sachkonto "4336"
			} elseif { "11000011" == $company_type_id && "DE" == $country_code } {
				set sachkonto "4400" 
			} elseif { "11000011" == $company_type_id && "noneu" == $country_group } {
				set sachkonto "4338" 
			} else { set sachkonto "" }
	} elseif { "FUD" == $agent_templ || "PAN" == $agent_templ } {
 			if { "11000010" == $company_type_id && "CH" == $country_code } {
				set sachkonto "4000" 
			} elseif { "11000010" == $company_type_id && "CH" != $country_code } {
				set sachkonto "4000" 
			} elseif { "11000011" == $company_type_id && "CH" == $country_code } {
				set sachkonto "4000" 
			} elseif { "11000011" == $company_type_id && "CH" != $country_code } {
				set sachkonto "4000" 
			} elseif { "56" == $company_type_id || "58" == $company_type_id && "CH" == $country_code } {
				set sachkonto "5201" 
			} elseif { "56" == $company_type_id || "58" == $company_type_id && "CH" != $country_code } {
				set sachkonto "5201" 
			} else { set sachkonto "" }
   } else { set sachkonto "" 
	  }

# Sonderkonten

		if { "Projektaufwand" == $cost_center_name } {
					set sachkonto "5201" 
		} elseif { "Projektmanagement" == $cost_center_name } {
					set sachkonto "5210" 
		} elseif { "Domainverwaltung" == $cost_center_name } {
					set sachkonto "5901" 
		} elseif { "Virtuelles Office" == $cost_center_name } {
					set sachkonto "5902" 
		} elseif { "Programmierung" == $cost_center_name } {
					set sachkonto "5903" 
		} elseif { "Verwaltung" == $cost_center_name } {
					set sachkonto "5904" 
		} elseif { "Verwaltung System" == $cost_center_name } {
					set sachkonto "5905" 
		} elseif { "Betreuung Website" == $cost_center_name } {
					set sachkonto "5907" 
		} elseif { "Werbung" == $cost_center_name } {
					set sachkonto "6600" 
		} elseif { "Telefon" == $cost_center_name } {
					set sachkonto "6805" 
		} elseif { "Telefax und Internet" == $cost_center_name } {
					set sachkonto "6810" 
		} elseif { "Buerobedarf" == $cost_center_name } {
					set sachkonto "6815" 
		} elseif { "Fortbildungskosten" == $cost_center_name } {
					set sachkonto "6821" 
		} elseif { "Abschluss- und Pruefungskosten" == $cost_center_name } {
					set sachkonto "6827" 
		} elseif { "Buchfuehrungskosten" == $cost_center_name } {
					set sachkonto "6830" 
		} elseif { "Mieten fuer Einrichtungen" == $cost_center_name } {
					set sachkonto "6835" 
		} elseif { "Nebenkosten Geldverkehr" == $cost_center_name } {
					set sachkonto "6855" 
		} 





### Suche ob Sonderkonten parent von cost_center, kann eigentlich weg#######
##if { "Sonderkonten" != $cost_center_name } {
##	
##	set ccname $cost_center_name
##	set ccid $cost_center_id
##	set ccpid "
##				select ccp.parent_id 
##				from im_cost_centers ccp 
##				where ccp.cost_center_id = :ccid
##				"	
##	set ccskid "
##				select ccsk.cost_center_id 
##				from im_cost_centers ccsk 
##				where ccsk.cost_center_name = \"Sonderkonten\"
##				"
##	while { "" != $ccpid || $ccid ne $ccskid } {

##			set ccid "
##				select ccsub.parent_id 
##				from im_cost_centers ccsub
##				where ccsub.cost_center_id = :ccid					
##				"
##			} 
##		set ccpid "
##				select ccsk.parent_id 
##				from im_cost_centers ccsk 
##				where ccsk.cost_center_name = \"Sonderkonten\"
##				"	
##		
##	if { "" == $parent_id } {
##				set sonderkonto "f"
##			} elseif { $ccid eq $ccskid} {
##						set sonderkonto "t"			
##					}
##			 
##}					
############### ende suche nach sonderkonten als parent###############
    
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
