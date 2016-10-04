# /packages/intranet-core/www/companies/upload-companies-2.tcl
#
# Copyright (C) 1998-2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Read a .csv-file with header titles exactly matching
    the data model and insert the data into "users" and
    "acs_rels".

    @author various@arsdigita.com
    @author frank.bergmann@project-open.com
} {
    upload_file
}

set current_user_id [ad_maybe_redirect_for_registration]
set page_title "Upload Companies HMD"
set page_body "<ul>"
set context_bar [im_context_bar [list "/intranet-cust-fud/hmd" "HMD"] $page_title]

# Get the file from the user.
# number_of_bytes is the upper-limit
set max_n_bytes [ad_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
im_security_alert_check_tmpnam -location "upload-companies-2.tcl" -value $tmp_filename
if { $max_n_bytes && ([file size $tmp_filename] > $max_n_bytes) } {
    ad_return_complaint 1 "Your file is larger than the maximum permissible upload size:  [util_commify_number $max_n_bytes] bytes"
    return
}

# strip off the C:\directories... crud and just get the file name
if ![regexp {([^//\\]+)$} $upload_file match company_filename] {
    # couldn't find a match
    set company_filename $upload_file
}

if {[regexp {\.\.} $company_filename]} {
    set error "Filename contains forbidden characters"
    ad_returnredirect "/error.tcl?[export_url_vars error]"
}

if {![file readable $tmp_filename]} {
    ad_return_complaint 1 "Unable to read the file '$tmp_filename'. <br>
    Please check the file permissions or contact your system administrator.\n"
    ad_script_abort
}

# ------------------------------------------------
set file [open $tmp_filename]
fconfigure $file -encoding "utf-8"
set csv_files_content [read $file]
set csv_files [split $csv_files_content "\n"]
close $file


set separator [im_csv_guess_separator $csv_files]
ns_log Notice "upload-companies-2: trying with separator=$separator"
# Split the header into its fields
set csv_header [string trim [lindex $csv_files 0]]
set csv_header_fields [im_csv_split $csv_header $separator]
set csv_header_len [llength $csv_header_fields]
set values_list_of_lists [im_csv_get_values $csv_files_content $separator]

set return_csv ""

# ------------------------------------------------------------
# Render Result Header

ad_return_top_of_page "
        [im_header]
        [im_navbar]
"


# ------------------------------------------------------------

set cnt 0
set new_company_html ""
set change_number_html ""

# Get the companies in a list of lists
set company_list [db_list_of_lists companies "select lower(company_name), company_id from im_companies"]
foreach csv_line_fields $values_list_of_lists {
    incr cnt

	# ---------------------------------------------------------------
	# We assume fixed position in the CSV
	# ---------------------------------------------------------------
	set hmd_company_id [lindex $csv_line_fields 0]
	set company_id ""
	set company_search_name [lindex $csv_line_fields 1]
	set company_name [string trim [string tolower [lindex $csv_line_fields 2]]]
#    set company_name [encoding convertfrom iso8859-1 $company_name]
#   	set company_name [im_mangle_unicode_accents $company_name]

    # -------------------------------------------------------
    # Empty company_name
    # => Skip it completely
    if {[empty_string_p $company_name]} {
    	ns_write "<li>'$company_name': Skipping, company name can not be empty.\n"
		continue	
    }

    # Check if the company already exists
    set company_info [lsearch -index 0 -all -inline $company_list $company_name]
	if {$company_info eq ""} {
		set company_id_info [lsearch -index 1 -all -inline $company_list $hmd_company_id]
		set po_company_name [string trim [lindex [lindex $company_id_info 0] 0]]
		if {![string equal $company_name $po_company_name]} {
			append new_company_html "<tr><td>$hmd_company_id</td><td>$company_name</td><td>$po_company_name</td></tr>"	
		}

#		ns_log Notice "New company $company_name - $hmd_company_id - [lindex [lindex $company_id_info 0] 0]"
	} else {

		set company_id [lindex [lindex $company_info 0] 1]		
		ns_log Notice "$company_info :: [lindex $company_info 0]"
		if {$hmd_company_id ne $company_id} {
			# Return the new number
			append change_number_html "<li>$company_name ($company_search_name): ${hmd_company_id} => ${company_id}</li>"
#			ns_log Notice "Change $company_name ($company_search_name): ${hmd_company_id} => ${company_id}"
		} 
	}
}

ns_write "<table><tr><th>HMD Company ID</th><th>HMD Company Name</th><th>PO Company Name</th></tr>$new_company_html</table><p>CHANGED</p><ul>$change_number_html</ul><p>\n"


# ------------------------------------------------------------
# Render Report Footer

ns_write [im_footer]


