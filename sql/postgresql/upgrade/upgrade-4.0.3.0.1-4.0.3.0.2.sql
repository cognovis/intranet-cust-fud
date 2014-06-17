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