# 
#
# Copyright (c) 2011, cognovís GmbH, Hamburg, Germany
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
 
ad_page_contract {
    
    Turns a quote into an order for FUD
    
    @author <yourname> (<your email>)
    @creation-date 2012-03-11
    @cvs-id $Id$
} {
    project_id:integer
} -properties {
} -validate {
} -errors {
}

# Double Click protection
if {[nsv_exists quote2order_projects $project_id]} {
    ad_return_error "Double Click !!!" "Your project is currently being processed. Please be patient and try again in 5 seconds <a href='[export_vars -base "/intranet/projects/view" -url {project_id}]'>here</a>"
}

nsv_set quote2order_projects $project_id 1

# First check if the project has already an invoice
set invoice_id [db_string invoice "select cost_id from im_costs where project_id = :project_id and cost_type_id = [im_cost_type_invoice] order by cost_id desc limit 1" -default ""]

if {"" != $invoice_id} {
    ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
}

# Get all information about the quote and customer and project
db_1row customer_and_project_info "select project_type_id, project_status_id, now() as effective_date, project_nr as original_project_nr, c.company_id, p.start_date, p.end_date, p.interco_company_id, p.processing_time, to_char(now(),'YYYY-MM-DD') as new_start_date, to_char(end_date, 'HH24:MI') as end_time, company_status_id from im_projects p, im_companies c where p.company_id = c.company_id and p.project_id = :project_id"

# Get the old project path
set old_project_path [im_filestorage_project_path $project_id]

if {[im_project_status_potential] != $project_status_id} {
    ad_return_error "Double Click !!!" "Your project is currently being processed. Please be patient and try again in 5 seconds"
}

# Set the new date
set new_end_date [db_string new_end_date "select to_timestamp('$new_start_date $end_time','YYYY-MM-DD HH24:MI') + '$processing_time days' from im_projects where project_id = :project_id"]

# Define the new project_number
if {28022 == $interco_company_id} {
    set project_nr [db_string fud_project "select max(project_nr) from im_projects where project_nr like '9%'"]
    incr project_nr
} elseif {552735 == $interco_company_id} {
    set project_nr [db_string fud_project "select max(project_nr) from im_projects where project_nr like '3%'"]
    incr project_nr
} elseif {279215 == $interco_company_id} {
    set project_nr [db_string fud_project "select max(project_nr) from im_projects where project_nr like 'Z%'"]
    set project_nr [string trim $project_nr "Z"]
    incr project_nr
    set project_nr "Z$project_nr"
}

# change the project_nr and record the new project_nr in the quote
db_dml update_project_nr "update im_projects set project_nr = :project_nr, project_path = :project_nr, project_name = :project_nr, project_status_id = [im_project_status_open],quote_nr = :original_project_nr, quote_date = :start_date, start_date = now(), end_date = :new_end_date where project_id = :project_id"

ns_log Notice "Quote2Order Change project number to $project_nr"

# Set the customer to active if not already done so

if {[im_company_status_active] != $company_status_id} {
    db_dml make_active "update im_companies set company_status_id = [im_company_status_active] where company_id = :company_id"
    set effective_date $new_start_date
} else {
    # It is a customer, effective_date for the invoice should be
    # project end date
    set effective_date $new_end_date
}


# Change End date of all tasks
db_dml change_task_end_dates "update im_trans_tasks set end_date = :new_end_date where project_id = :project_id"

# Create a new invoice.
# If new customer create a new invoice with the effective_date of now,
# else project_end_date

set quote_id [db_string quote "select cost_id from im_costs where project_id = :project_id and cost_type_id = [im_cost_type_quote] order by cost_id desc limit 1" -default ""]
if {"" != $quote_id} {
    # Copy the invoice
    set invoice_id [im_invoice_copy_new -source_invoice_ids $quote_id -target_cost_type_id [im_cost_type_invoice]]
    set invoice_nr "I$project_nr"
    db_dml update_effective_date "update im_costs set cost_name = :invoice_nr, effective_date = :effective_date, delivery_date = :new_end_date, cost_status_id=11000162 where cost_id = :invoice_id"
    db_dml update_invoice_nr "update im_invoices set invoice_nr = :invoice_nr where invoice_id = :invoice_id"
}

ns_log Notice "Updated invoices"
# Change the template of the Offer and change the name.
set confirmation_nr "C$project_nr"
set confirmation_template_id [db_string confirmation_id "select aux_int2 from im_categories, im_costs where template_id = category_id and cost_id = :quote_id"]

db_dml update_quote "update im_costs set cost_name = :confirmation_nr, template_id = :confirmation_template_id, effective_date = now(), delivery_date = :new_end_date where cost_id = :quote_id"
db_dml update_invoice_nr "update im_invoices set invoice_nr = :confirmation_nr where invoice_id = :quote_id"

ns_log Notice "Updated confirmation number and template"

# Move the folder to the new project_path
if {[file exists $old_project_path]} {
    file rename $old_project_path [im_filestorage_project_path_helper $project_id]
}

util_memoize_flush [list im_filestorage_base_path_helper project $project_id]
util_memoize_flush [list im_filestorage_project_path_helper $project_id]

ns_log Notice "renamed the files from $old_project_path to [im_filestorage_project_path_helper $project_id]"

# Write Audit Trail
im_project_audit -project_id $project_id -type_id $project_type_id -status_id $project_status_id -action after_update

# Forward the Users to the new invoice view.tcl page
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
