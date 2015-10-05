-- 
-- 
-- 
-- @author <yourname> (<your email>)
-- @creation-date 2012-06-08
-- @cvs-id $Id$
--
SELECT acs_log__debug('/packages/intranet-cust-fud/sql/postgresql/upgrade/upgrade-4.0.3.0.0-4.0.3.0.1.sql','');
-- PM Association
delete from im_categories where category_id = 1350;
insert into im_categories (
        category_id, category, category_type,
        category_gif, category_description)
values (1350, 'Quality Manager', 'Intranet Biz Object Role',
        'q', 'Quality Manager');
insert into im_biz_object_role_map values ('im_project',85,1350);

delete from im_categories where category_id = 1351;
insert into im_categories (
        category_id, category, category_type,
        category_gif, category_description)
values (1351, 'Project Manager (FL)', 'Intranet Biz Object Role',
        'p', 'Project Manager (FL)');
insert into im_biz_object_role_map values ('im_project',85,1351);

-- Ammend the views
update im_view_columns set column_render_tcl = '"<A HREF=/intranet/users/view?user_id=$project_lead_id>$lead_name</A>"', column_name = 'Account Manager' where column_id = 2025;
update im_categories set category_gif = 'a' where category_id = 1301;

delete from im_view_columns where column_name = 'Quality Manager' and view_id = 20;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (nextval('im_view_columns_seq'),20,NULL,'Quality Manager',
'"[fud_member_list -project_id $project_id -object_role_id 1350]"','','',27,'');

delete from im_view_columns where column_name = 'Project Manager (FL)' and view_id = 20;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (nextval('im_view_columns_seq'),20,NULL,'Project Manager (FL)',
'"[fud_member_list -project_id $project_id -object_role_id 1351]"','','',26,'');