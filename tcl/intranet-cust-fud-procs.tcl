# 

## Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
# 

ad_library {
    
    FUD custom procs
    
    @author <yourname> (<your email>)
    @creation-date 2012-03-11
    @cvs-id $Id$
}

ad_proc -public fud_status_id {
    -project_status_id
} {
    if {"" eq $project_status_id} {set project_status_id 0}
    return $project_status_id
}

ad_proc -public fud_int2_id {
    -category_id
} {
    Return the profile_id to a role
} {
    return 
}

ad_proc -public fud_member_list_1 {
    -project_id
    -object_role_id
} {
    Return the Names of the PMS
} {
    return [util_memoize [list fud_member_list_helper -project_id $project_id -object_role_id $object_role_id]]
}

ad_proc -public fud_member_list {
    -project_id
    -object_role_id
} {
    Return the Names of the PMS
} {
    set pm_list [list]
    set sql "
	select im_name_from_id(object_id_two) as pm_name,object_id_two as pm_id
	from
	       acs_rels r, im_biz_object_members bo
	where
               r.object_id_one = :project_id and
	       r.rel_id = bo.rel_id and
               bo.object_role_id = :object_role_id
    "
    db_foreach pm $sql {
	lappend pm_list "<A HREF=/intranet/users/view?user_id=$pm_id>$pm_name</A>"
    }

    
    if {0 == [llength $pm_list]} {

	set user_id [ad_conn user_id]
	set profile_id [util_memoize [list db_string profile_id "select aux_int2 from im_categories where category_id = $object_role_id"]]

	# Check if the user is in the correct group
	if {[im_profile::member_p -profile_id $profile_id -user_id $user_id]} {
	    set assign_url [export_vars -base "/intranet/member-add-2" -url {{user_id_from_search "$user_id"} {object_id $project_id} {role_id $object_role_id} {return_url "[util_get_current_url]"}}]
	    return "<a href=\"$assign_url\">Assign me</a>"
	} else {
	    return "Assign me"
	}
    } else {
	return [join $pm_list "<br />"]
    }
}


#procs update 
ad_proc -public fud_update_old_projects {
    
} {
    change quote project status after 30 days without answer
} {
    db_dml update_kv_status {
	UPDATE im_projects  SET project_status_id = 11000007 
	WHERE project_status_id = 71 
	AND start_date < current_date - 30
	AND project_nr LIKE '1%'
    }
}



ad_proc -public etm_update_wrong_order_status {
    
} {
    change invoice status to outstanding if set to created 
} {
    db_dml update_kv_status {
      update im_costs set cost_status_id = 3804 
      where cost_type_id = 3700
      and cost_status_id = 3802
    }
}



# ---------------------------------------------------------------
# Procdures to create an invoice PDF
# ---------------------------------------------------------------

ad_proc -public fud_create_invoice_pdf {
    {-invoice_id:required}
} {
    Create a PDF for the current invoice and store it with the naming convention
    
    InvoiceNr_CustomerName_InvoiceDate_ChangeDate.pdf
    
    in a special folder.
    
    @param invoice_id invoice for which to create the PDF file 
} {

    set user_id [ad_maybe_redirect_for_registration]
    set company_project_nr_exists [im_column_exists im_projects company_project_nr]

    # ---------------------------------------------------------------
    # Get everything about the invoice
    # ---------------------------------------------------------------
    
    # A Customer document
    set customer_or_provider_join "and ci.customer_id = c.company_id"
    set provider_company "Customer"
    set recipient_select "ci.customer_id as recipient_company_id"    
    
    db_1row invoice_info "
        select
            c.*,
            i.*,
                    $recipient_select ,
            ci.effective_date::date + ci.payment_days AS due_date,
            to_char(ci.effective_date,'YYYYMMDD') as ansi_invoice_date,
            ci.effective_date AS invoice_date,
            ci.cost_status_id AS invoice_status_id,
            ci.cost_type_id AS invoice_type_id,
            ci.template_id AS invoice_template_id,
            ci.*,
            ci.note as cost_note,
            ci.project_id as cost_project_id,
            to_date(to_char(ci.effective_date, 'YYYY-MM-DD'), 'YYYY-MM-DD') + ci.payment_days as calculated_due_date,
            im_cost_center_name_from_id(ci.cost_center_id) as cost_center_name,
            im_category_from_id(ci.cost_status_id) as cost_status,
            im_category_from_id(ci.template_id) as template,
            im_category_from_id(c.default_payment_method_id) as default_payment_method,
            im_category_from_id(c.company_type_id) as company_type
        from
            im_invoices i,
            im_costs ci,
                im_companies c
        where 
            i.invoice_id=:invoice_id
            and ci.cost_id = i.invoice_id
            $customer_or_provider_join
    "

    if {![db_0or1row office_info_query "
        select *
        from im_offices
        where office_id = :invoice_office_id
    "]} {
	ns_log Notice "No office found for $invoice_id :: $invoice_office_id :: $company_name"
	return
	ad_script_abort
    }

    # ---------------------------------------------------------------
    # Check if this is an ODT template, otherwise stop
    # ---------------------------------------------------------------

    set template_type ""
    if {0 != $invoice_template_id} {
    
        # New convention, "invoice.en_US.adp"
        if {[regexp {(.*)\.([_a-zA-Z]*)\.([a-zA-Z][a-zA-Z][a-zA-Z])} $template match body loc template_type]} {
            set locale $loc
        }
    }
    
    # don't continue if it is not an ODT template
    if {$template_type ne "odt"} {
        return
        ad_script_abort
    }
    
    
    db_0or1row accounting_contact_info "
        select
                im_name_from_user_id(person_id) as company_contact_name,
                im_email_from_user_id(person_id) as company_contact_email,
                first_names as company_contact_first_names,
                last_name as company_contact_last_name
        from    persons
        where   person_id = :company_contact_id
    "
    
    # Get contact person's contact information
    set contact_person_work_phone ""
    set contact_person_work_fax ""
    set contact_person_email ""
    db_0or1row contact_info "
        select
            work_phone as contact_person_work_phone,
            fax as contact_person_work_fax,
            im_email_from_user_id(user_id) as contact_person_email
        from
            users_contact
        where
            user_id = :company_contact_id
    "
    
    
    # ----------------------------------------------------------------------------------------
    # Check if there are Dynamic Fields of type date and localize them 
    # ----------------------------------------------------------------------------------------
    
    set date_fields [list]
    set column_sql "
            select  w.widget_name,
                    aa.attribute_name
            from    im_dynfield_widgets w,
                    im_dynfield_attributes a,
                    acs_attributes aa
            where   a.widget_name = w.widget_name and
                    a.acs_attribute_id = aa.attribute_id and
                    aa.object_type = 'im_invoice' and
                    w.widget_name = 'date'
    "
    db_foreach column_list_sql $column_sql {
        set y ${attribute_name}
        set z [lc_time_fmt [subst $${y}] "%x" $locale]
        set ${attribute_name} $z
    }
    
    # ---------------------------------------------------------------
    # Format Invoice date information according to locale
    # ---------------------------------------------------------------
    
    set invoice_date_pretty [lc_time_fmt $invoice_date "%x" $locale]
    #set delivery_date_pretty2 [lc_time_fmt $delivery_date "%x" $locale]
    set delivery_date_pretty2 $delivery_date
    
    set calculated_due_date_pretty [lc_time_fmt $calculated_due_date "%x" $locale]
    
    # ---------------------------------------------------------------
    # Add subtotal + VAT + TAX = Grand Total
    # ---------------------------------------------------------------
    
    if {[im_column_exists im_costs vat_type_id]} {
        # get the VAT note. We do not overwrite the VAT value stored in
        # the invoice in case the default rate has changed for the
        # vat_type_id and this is just a reprint of the invoice
        set vat_note [im_category_string1 -category_id $vat_type_id -locale $locale]
    } else {
        set vat_note ""
    }
    
    # -------------------------
    # Deal with payment terms and variables in them
    # -------------------------
    
    if {"" == $payment_term_id} {
        set payment_term_id [db_string payment_term "select payment_term_id from im_companies where company_id = :recipient_company_id" -default ""]
    }
    set payment_terms [im_category_from_id -locale $locale $payment_term_id]
    set payment_terms_note [im_category_string1 -category_id $payment_term_id -locale $locale]
    eval [template::adp_compile -string $payment_terms_note]
    set payment_terms_note $__adp_output
    
    # -------------------------
    # Deal with payment method and variables in them
    # -------------------------
    
    set payment_method [im_category_from_id -locale $locale $payment_method_id]
    set payment_method_note [im_category_string1 -category_id $payment_method_id -locale $locale]
    eval [template::adp_compile -string $payment_method_note]
    set payment_method_note $__adp_output
    set invoice_payment_method_l10n $payment_method
    set invoice_payment_method $payment_method
    set invoice_payment_method_desc $payment_method_note
    
    # -------------------------------
    # Support for cost center text
    # -------------------------------
    set cost_center_note [lang::message::lookup $locale intranet-cost.cc_invoice_text_${cost_center_id} " "]
    
    # Set these values to 0 in order to allow to calculate the
    # formatted grand total
    if {"" == $vat} { set vat 0}
    if {"" == $tax} { set tax 0}
        
    # ---------------------------------------------------------------
    # Determine the country name and localize
    # ---------------------------------------------------------------
    
    set country_name ""
    if {"" != $address_country_code} {
        set query "
        select  cc.country_name
        from    country_codes cc
        where   cc.iso = :address_country_code"
        if { ![db_0or1row country_info_query $query] } {
            set country_name $address_country_code
        }
        set country_name [lang::message::lookup $locale intranet-core.$country_name $country_name]
    }

    # ---------------------------------------------------------------
    # Calculate the grand total
    # ---------------------------------------------------------------

    # Number formats
    set cur_format [im_l10n_sql_currency_format]
    set vat_format $cur_format
    set tax_format $cur_format
    
    # Rounding precision can be between 2 (USD,EUR, ...) and -5 (Old Turkish Lira, ...).
    set rounding_precision 2
    set rounding_factor [expr exp(log(10) * $rounding_precision)]
    set rf $rounding_factor

    db_1row calc_grand_total "select	i.*,
        round(i.grand_total * :vat / 100 * :rf) / :rf as vat_amount,
        round(i.grand_total * :tax / 100 * :rf) / :rf as tax_amount,
        i.grand_total
            + round(i.grand_total * :vat / 100 * :rf) / :rf
            + round(i.grand_total * :tax / 100 * :rf) / :rf
        as total_due
    from
        (select
            max(i.currency) as currency,
            sum(i.amount) as subtotal,
            round(sum(i.amount) * :surcharge_perc::numeric) / 100.0 as surcharge_amount,
            round(sum(i.amount) * :discount_perc::numeric) / 100.0 as discount_amount,
            sum(i.amount)
                + round(sum(i.amount) * :surcharge_perc::numeric) / 100.0
                + round(sum(i.amount) * :discount_perc::numeric) / 100.0
            as grand_total
        from 
            (select	ii.*,
                round(ii.price_per_unit * ii.item_units * :rf) / :rf as amount
            from	im_invoice_items ii,
                im_invoices i
            where	i.invoice_id = ii.invoice_id
                and i.invoice_id = :invoice_id
            ) i
        ) i"
    
    set subtotal_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $subtotal+0] $rounding_precision] "" $locale]
    set vat_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $vat_amount+0] $rounding_precision] "" $locale]
    set tax_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $tax_amount+0] $rounding_precision] "" $locale]
    
    set vat_perc_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $vat+0] $rounding_precision] "" $locale]
    set tax_perc_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $tax+0] $rounding_precision] "" $locale]
    set grand_total_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $grand_total+0] $rounding_precision] "" $locale]
    set total_due_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $total_due+0] $rounding_precision] "" $locale]
    set discount_perc_pretty $discount_perc
    set surcharge_perc_pretty $surcharge_perc
    
    set discount_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $discount_amount+0] $rounding_precision] "" $locale]
    set surcharge_amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $surcharge_amount+0] $rounding_precision] "" $locale]

    # ---------------------------------------------------------------
    # Get everything about the "internal" company
    # ---------------------------------------------------------------
    
    set internal_company_id [im_company_internal]
    
    db_1row internal_company_info "
        select
            c.company_name as internal_name,
            c.company_path as internal_path,
            c.vat_number as internal_vat_number,
            c.site_concept as internal_web_site,
            im_name_from_user_id(c.manager_id) as internal_manager_name,
            im_email_from_user_id(c.manager_id) as internal_manager_email,
            c.primary_contact_id as internal_primary_contact_id,
            im_name_from_user_id(c.primary_contact_id) as internal_primary_contact_name,
            im_email_from_user_id(c.primary_contact_id) as internal_primary_contact_email,
            c.accounting_contact_id as internal_accounting_contact_id,
            im_name_from_user_id(c.accounting_contact_id) as internal_accounting_contact_name,
            im_email_from_user_id(c.accounting_contact_id) as internal_accounting_contact_email,
            o.office_name as internal_office_name,
            o.fax as internal_fax,
            o.phone as internal_phone,
            o.address_line1 as internal_address_line1,
            o.address_line2 as internal_address_line2,
            o.address_city as internal_city,
            o.address_state as internal_state,
            o.address_postal_code as internal_postal_code,
            o.address_country_code as internal_country_code,
            cou.country_name as internal_country_name,
            paymeth.category_description as internal_payment_method_desc
        from
            im_companies c
            LEFT OUTER JOIN im_offices o ON (c.main_office_id = o.office_id)
            LEFT OUTER JOIN country_codes cou ON (o.address_country_code = iso)
            LEFT OUTER JOIN im_categories paymeth ON (c.default_payment_method_id = paymeth.category_id)
        where
            c.company_id = :internal_company_id
    "
    
    
    # Set the email and name of the current user as internal contact
    db_1row accounting_contact_info "
        select
        im_name_from_user_id(:user_id) as internal_contact_name,
        im_email_from_user_id(:user_id) as internal_contact_email,
        uc.work_phone as internal_contact_work_phone,
        uc.home_phone as internal_contact_home_phone,
        uc.cell_phone as internal_contact_cell_phone,
        uc.fax as internal_contact_fax,
        uc.wa_line1 as internal_contact_wa_line1,
        uc.wa_line2 as internal_contact_wa_line2,
        uc.wa_city as internal_contact_wa_city,
        uc.wa_state as internal_contact_wa_state,
        uc.wa_postal_code as internal_contact_wa_postal_code,
        uc.wa_country_code as internal_contact_wa_country_code
        from
        users u
        LEFT OUTER JOIN users_contact uc ON (u.user_id = uc.user_id)
        where
        u.user_id = :user_id
    "
    
    # ---------------------------------------------------------------
    # Get more about the invoice's project
    # ---------------------------------------------------------------


    # We give priority to the project specified in the cost item,
    # instead of associated projects.
    if {"" != $cost_project_id && 0 != $cost_project_id} {
        set rel_project_id $cost_project_id
    } else {
        
        set rel_project_id [db_string related_projects "
            select  distinct r.object_id_one
            from    acs_rels r, im_projects p
            where   r.object_id_one = p.project_id
            and     r.object_id_two = :invoice_id
            order by r.object_id_one
            limit 1
        " -default 0]
    }
    
    set project_short_name_default ""
    db_0or1row project_info_query "
            select
                    project_nr as project_short_name_default,                                                                                   
                    im_category_from_id(project_type_id) as project_type_pretty                                                                 
            from                                                                                                                                
                    im_projects                                                                                                                 
            where                                                                                                                               
                    project_id = :rel_project_id                                                                                                
     "                                                                                                                                          
    
    set customer_project_nr_default ""
    if {$company_project_nr_exists && $rel_project_id} {
        set customer_project_nr_default [db_string project_nr_default "select company_project_nr from im_projects where project_id=:rel_project_id" -default ""]
    }
    
    
    # ---------------------------------------------------------------
    # Prepare the template
    # ---------------------------------------------------------------

    # Check if the given locale throws an error
    # Reset the locale to the default locale then
    if {[catch {
        lang::message::lookup $locale "intranet-core.Reporting"
    } errmsg]} {
        set locale $user_locale
    }
    
    set odt_tmp_path [ns_tmpnam]
  
    ns_mkdir $odt_tmp_path
    
    # The document 
    set odt_zip "${odt_tmp_path}.odt"
    set odt_content "${odt_tmp_path}/content.xml"
    set odt_styles "${odt_tmp_path}/styles.xml"
    
    # ------------------------------------------------
    # Create a copy of the ODT
    set invoice_template_base_path [ad_parameter -package_id [im_package_invoices_id] InvoiceTemplatePathUnix "" "/tmp/templates/"]
    set invoice_template_path "$invoice_template_base_path/$template"
    ns_cp $invoice_template_path $odt_zip
    exec unzip -d $odt_tmp_path $odt_zip 
    
    # ------------------------------------------------
    # Read the content.xml file
    set file [open $odt_content]
    fconfigure $file -encoding "utf-8"
    set odt_template_content [read $file]

    close $file
    
    # ------------------------------------------------
    # Search the <row> ...<cell>..</cell>.. </row> line
    # representing the part of the template that needs to
    # be repeated for every template.

    # Get the list of all "tables" in the document
    set odt_doc [dom parse $odt_template_content]
    set root [$odt_doc documentElement]
    set odt_table_nodes [$root selectNodes "//table:table"]

    # Search for the table that contains "@item_name_pretty"
    set odt_template_table_node ""
    foreach table_node $odt_table_nodes {
        set table_as_list [$table_node asList]
        if {[regexp {item_units_pretty} $table_as_list match]} { set odt_template_table_node $table_node }
    }

    # Deal with the the situation that we didn't find the line
    if {"" == $odt_template_table_node} {
        ns_log Error "
        <b>Didn't find table including '@item_units_pretty'</b>:<br>
        We have found a valid OOoo template at '$invoice_template_path'.
        However, this template does not include a table with the value
        above.
    "
        ad_script_abort
    }

    # Search for the 2nd table:table-row tag
    set odt_table_rows_nodes [$odt_template_table_node selectNodes "//table:table-row"]
    set odt_template_row_node ""
    set odt_template_row_count 0
    foreach row_node $odt_table_rows_nodes {
        set row_as_list [$row_node asList]
        if {[regexp {item_units_pretty} $row_as_list match]} { set odt_template_row_node $row_node }
        incr odt_template_row_count
    }
    
    if {"" == $odt_template_row_node} {
        ns_log Error "
            <b>Didn't find row including '@item_units_pretty'</b>:<br>
            We have found a valid OOoo template at '$invoice_template_path'.
            However, this template does not include a row with the value
            above.
        "
        ad_script_abort
    }
    
    # Convert the tDom tree into XML for rendering
    set odt_row_template_xml [$odt_template_row_node asXML]
    
    set ctr 1
    set oo_table_xml ""


    # ---------------------------------------------------------------
    # Prepare the invoice line items
    # ---------------------------------------------------------------
    db_foreach invoice_items "
        select
            i.*,
            p.*,
            now() as delivery_date_pretty,
            im_category_from_id(i.item_type_id) as item_type,
            im_category_from_id(i.item_uom_id) as item_uom,
            p.project_nr as project_short_name,
            round(i.price_per_unit * i.item_units * :rf) / :rf as amount,
            to_char(round(i.price_per_unit * i.item_units * :rf) / :rf, :cur_format) as amount_formatted,
            i.currency as item_currency
       from
            im_invoice_items i
            LEFT JOIN im_projects p on i.project_id=p.project_id
       where
            i.invoice_id=:invoice_id
       order by
            i.sort_order,
            i.item_type_id
    " {

        set amount_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $amount+0] $rounding_precision] "" $locale]
        set item_units_pretty [lc_numeric [expr $item_units+0] "" $locale]
        set price_per_unit_pretty [lc_numeric [im_numeric_add_trailing_zeros [expr $price_per_unit+0] $rounding_precision] "" $locale]

        # Insert a new XML table row into OpenOffice document
	    set item_uom [lang::message::lookup $locale intranet-core.$item_uom $item_uom]
	
	    # Replace placeholders in the OpenOffice template row with values
	    eval [template::adp_compile -string $odt_row_template_xml]
	    set odt_row_xml [intranet_oo::convert -content $__adp_output]
	
	    # Parse the new row and insert into OOoo document
	    set row_doc [dom parse $odt_row_xml]
	    set new_row [$row_doc documentElement]
	    $odt_template_table_node insertBefore $new_row $odt_template_row_node
	

	    incr ctr
    }
    
    # ---------------------------------------------------------------
    # Build the PDF file from the ODT
    # ---------------------------------------------------------------

    # ------------------------------------------------
    # Delete the original template row, which is duplicate
    $odt_template_table_node removeChild $odt_template_row_node
    
    # ------------------------------------------------
    # Process the content.xml file
    
    set odt_template_content [$root asXML -indent 1]
    set vars_escaped [list]

    # Escaping other vars used, skip vars already escaped for multiple lines  
    set lines [split $odt_template_content \n]
    foreach line $lines {
        set var_to_be_escaped ""
        regexp -nocase {@(.*?)@} $line var_to_be_escaped    
        regsub -all "@" $var_to_be_escaped "" var_to_be_escaped
        regsub -all ";noquote" $var_to_be_escaped "" var_to_be_escaped
        if { -1 == [lsearch $vars_escaped $var_to_be_escaped] } {
            if { "" != $var_to_be_escaped  } {
                if { [info exists $var_to_be_escaped] } {
                    set value [eval "set value \"$$var_to_be_escaped\""]
		    set value [encodeXmlValue $value]
		    regsub -all {\"} $value {'} value
                    set cmd "set $var_to_be_escaped \"$value\""
                    eval $cmd
                }
            }
        }
    }
    
    # Perform replacements
    regsub -all "&lt;%" $odt_template_content "<%" odt_template_content
    regsub -all "%&gt;" $odt_template_content "%>" odt_template_content
    
    # Rendering 
    if {[catch {
        eval [template::adp_compile -string $odt_template_content]
    } err_msg]} {
        set err_txt "Error rendering Template. You might have used a placeholder that is not available. Here's a detailed error message:<br/> <strong>$err_msg</strong><br/>"
        append err_txt "Check the Configuration Manuals at <a href='www.project-open.org'>www.project-open.org</a> for a list of placeholders available and more information and tips on configuring templates."
        ns_log Error "$err_text"
        ad_script_abort
    }
    
    set content $__adp_output
    
    # Save the content to a file.
    set file [open $odt_content w]
    fconfigure $file -encoding "utf-8"
    
    # Make some last minute conversions
    puts $file [intranet_oo::convert -content $content]
    flush $file
    close $file
    
    # Process the styles.xml file
    set file [open $odt_styles]
    fconfigure $file -encoding "utf-8"
    set style_content [read $file]
    close $file
    
    # Perform replacements
    eval [template::adp_compile -string $style_content]
    set style $__adp_output
    
    # Save the content to a file.
    set file [open $odt_styles w]
    fconfigure $file -encoding "utf-8"
    puts $file [intranet_oo::convert -content $style]
    flush $file
    close $file
    
    # Replace the files inside the odt file by the processed files
    exec zip -j $odt_zip $odt_content
    exec zip -j $odt_zip $odt_styles
    
    db_release_unused_handles

    # ---------------------------------------------------------------
    # Create the PDF file and rename it in the proper location
    # ---------------------------------------------------------------
    set pdf_path [im_filestorage_cost_path invoices]
    
    regsub -all {[^a-zA-Z0-9_]} $company_name "" pdf_company_name
    set pdf_company_name [string range $pdf_company_name 0 19]
    
    set ansi_change_date [clock format [clock seconds] -format "%Y%m%d"]
        
    set pdf_filename "${invoice_nr}_${pdf_company_name}_${ansi_invoice_date}_${ansi_change_date}.pdf"
    
    set output_file "${pdf_path}/$pdf_filename"
    # Remove the file if it exists
    
    
    # convert the PDF
    intranet_oo::jodconvert -oo_file $odt_zip -output_file $output_file

    ns_log Notice "FUD Invoices:: Created $output_file"
    return $output_file
    
}

ad_proc -public -callback im_invoice_after_create -impl aa_fud_store_invoice {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
} {
    Store the invoice after creation
} {
    # Check if this is an invoice in active status
    if {$status_id eq "3812"} {
        return
        ad_script_abort
    }
    
    # Check if this invoice is of customer type
    if {$type_id ne "3700"} {
        return
        ad_script_abort        
    }
    
    # Create the invoice
    fud_create_invoice_pdf -invoice_id $object_id
}

ad_proc -public -callback im_invoice_after_update -impl aa_fud_store_invoice {
    {-object_id:required}
    {-status_id ""}
    {-type_id ""}
} {
    Store the invoice after creation
} {
    # Check if this is an invoice in active status
    if {$status_id eq "3812"} {
        return
        ad_script_abort
    }
    
    # Check if this invoice is of customer type
    if {$type_id ne "3700"} {
        return
        ad_script_abort        
    }
    
    # Create the invoice
    fud_create_invoice_pdf -invoice_id $object_id
}



ad_proc -public -callback im_project_new_redirect -impl aa_fud_trans_redirect {
    {-object_id ""}
    {-status_id ""}
    {-type_id ""}
    {-project_id ""}
    {-parent_id ""}
    {-company_id ""}
    {-project_type_id ""}
    {-project_name ""}
    {-project_nr ""}
    {-workflow_key ""}
    {-return_url ""}
} {
    redirect
} {

# Returnredirect to translations for translation projects
    if {[apm_package_installed_p "intranet-translation"] && [im_category_is_a $project_type_id [im_project_type_translation]] && $project_id == ""} {
	ad_returnredirect [export_vars -base "/intranet-translation/projects/new" -url {project_type_id company_id parent_id project_nr project_name workflow_key return_url}]
    }
}



# etm defaults
# company defaults
# invoice-template new company
ad_proc -public im_etm_invoicetemplate_default {} {
	set invt ""
	
	if {[im_profile::member_p -profile_id 467 -user_id [ad_conn user_id]]} {
	  switch -glob [im_email_from_user_id_helper [ad_conn user_id]] {
	    *@fachuebersetzungsdienst.com {set invt 11000249} 
	    *@panoramalanguages.com {set invt 11000300} 
	    *@fachuebersetzungsagentur.com {set invt 11000228}
	    *@fachuebersetzungsservice.com {set invt 11000228}
	    }
	    return $invt
	} else { return "" }
}


# quote-template new company
ad_proc -public im_etm_quotetemplate_default {} {
	set qtt ""
	
	if {[im_profile::member_p -profile_id 467 -user_id [ad_conn user_id]]} {
	  switch -glob [im_email_from_user_id_helper [ad_conn user_id]] {
	    *@fachuebersetzungsdienst.com {set qtt 11000253} 
	    *@panoramalanguages.com {set qtt 11000304} 
	    *@fachuebersetzungsagentur.com {set qtt 11000220}
	    *@fachuebersetzungsservice.com {set qtt 11000220}
	    }
	    return $qtt
	  } else { return "" }
}

# vat-rate default
ad_proc -public im_etm_vatbyagent_default {} {
	set vat ""
	
	#if {[im_profile::member_p -profile_id 467 -user_id [ad_conn user_id]]} {
	  switch -glob [im_email_from_user_id_helper [ad_conn user_id]] {
	    *@fachuebersetzungsdienst.com {set vat 42030} 
	    *@panoramalanguages.com {set vat 42030} 
	    *@fachuebersetzungsagentur.com {set vat 11000290}
	    *@fachuebersetzungsservice.com {set vat 11000290}
	    }
	    return $vat
	#} else { return "" }
}


# new project defaults
ad_proc -public im_etm_agency_by_cm_default {} {
	set agency_default ""
	if {[im_user_is_employee_p -user_id [ad_conn user_id]]} {
	  switch -glob [im_email_from_user_id_helper [ad_conn user_id]] {
	    *@fachuebersetzungsdienst.com {set agency_default 28022} 
	    *@panoramalanguages.com {set agency_default 552735} 
	    *@fachuebersetzungsagentur.com {set agency_default 279215}
	    *@fachuebersetzungsservice.com {set agency_default 279215}
	    }
	    return $agency_default
	    }
}




