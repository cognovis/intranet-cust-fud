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

ad_proc -public fud_update_old_projects {
    
} {
    Könntest Du bitte noch diese KV-Status-Aktualisierung einmal pro Tag (Woche würde auch reichen) über die DB rasen lassen
} {
    db_dml update_kv_status {
	UPDATE im_projects  SET project_status_id = 11000007 
	WHERE project_status_id = 71 
	AND start_date < current_date - 30
	AND project_nr LIKE '1%'
    }
}