-- 
-- 
-- 
-- @author <yourname> (<your email>)
-- @creation-date 2012-06-08
-- @cvs-id $Id$
--
SELECT acs_log__debug('/packages/intranet-cust-fud/sql/postgresql/upgrade/upgrade-4.0.3.0.1-4.0.3.0.2.sql','');

-- Change behaviour of project lists
update apm_parameter_values set attr_value = 0 where parameter_id = (select parameter_id from apm_parameters where parameter_name = 'ProjectListPageShowFilterWithMemberP');
update im_dynfield_attributes set also_hard_coded_p = 't' where acs_attribute_id in (select attribute_id from acs_attributes where attribute_name = 'source_language_id');
update im_dynfield_type_attribute_map set display_mode = 'none' where attribute_id in (select attribute_id from im_dynfield_attributes where acs_attribute_id in ( select attribute_id from acs_attributes where attribute_name = 'project_path'));

SELECT im_component_plugin__del_module('intranet-cognovis');
create or replace function inline_0 ()
returns integer as '
DECLARE
            v_plugin_id integer;

BEGIN
            SELECT plugin_id into v_plugin_id
            FROM im_component_plugins
            WHERE plugin_name = ''Project Base Data''
            AND package_name = ''intranet-core''
            AND page_url = ''/intranet/projects/view'';

            UPDATE im_component_plugins
            SET enabled_p = ''t''
            WHERE plugin_id = v_plugin_id;

            return 0;
end;' language 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();
        

            