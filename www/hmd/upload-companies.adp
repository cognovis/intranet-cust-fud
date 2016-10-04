<!-- packages/intranet-core/www/companies/new.adp -->
<!-- @author Juanjo Ruiz (juanjoruizx@yahoo.es) -->

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">
<master>
<property name="title">@page_title@</property>
<property name="context">@context_bar@</property>
<property name="main_navbar_label">companies</property>

<form enctype="multipart/form-data" method=POST action="upload-companies-2.tcl">
<%= [export_form_vars return_url] %>
    <table border=0>
     <tr> 
	<td>Filename</td>
	<td> 
	  <input type=file name=upload_file size=30>
	<%= [im_gif help "Use the &quot;Browse...&quot; button to locate your file, then click &quot;Open&quot;."] %>
	</td>
     </tr>
<!--
      <tr> 
	<td>Dynamic<br>Field<br>Transformation</td>
	<td> 
		<select name=transformation_key>
		<option value=none selected>None</option>
		<option value=reinisch_customers>reinisch Customers (Sales Rep & B-Org Customer Code)</option>
	</td>
      </tr>
-->
      <tr> 
	<td></td>
	<td> 
	  <input type=submit value="Submit and Upload">
	</td>
      </tr>
    </table>
</form>