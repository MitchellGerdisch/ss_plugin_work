name "LIB - Error Handling Utilities"
rs_ca_ver 20160622
short_description "RCL definitions for error handling functions"

package "utilities"

# Used for retry mechanism
define handle_retries($attempts) do
  if $attempts < 3
    $_error_behavior = "retry"
    sleep(60)
  end # If it fails 3 times just let it raise the error
end

# create an audit entry 
define log($summary, $details) do
  rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @@deployment, summary: $summary , detail: $details})
end

# run a rightscript by name
define run_script_by_name(@server, $script_name) do
  @script = find("right_scripts", { name: $script_name })
  $right_script_href=@script.href
  @tasks = @server.current_instance().run_executable(right_script_href: $right_script_href)
end

# Creates CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define createCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs_cm.credentials.get(filter: join(["name==",$cred_name]))
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs_cm.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
end

# Deletes CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define deleteCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs_cm.credentials.get(filter: join(["name==",$cred_name]))
    if logic_not(empty?(@cred))
      @cred.destroy()
    end
  end
end

define getLaunchInfo() return $execution_name, $userid, $execution_description do
  
  $execution_name = $name_array = split(@@deployment.name, "-")
  $name_array_size = size($name_array)
  $execution_name = join($name_array[0..($name_array_size-2)])
  
  $deployment_description_array = lines(@@deployment.description)
  $userid="tbd"
  $execution_description="tbd"
  foreach $entry in $deployment_description_array do
    if include?($entry, "Author")
      $userid = split(split(lstrip(split(split($entry, ":")[1], "(")[0]), '[`')[1],'`]')[0]
    elsif include?($entry, "CloudApp description:")
      $execution_description = lstrip(split(split($entry, ":")[1], "\"")[0])
    end
  end
  
  # Must have a value otherwise trouble will occur when trying to tag.
  # So if user didn't write a description when launching, just set it to the name the user gave the execution.
  if $execution_description == ""
    $execution_description = $execution_name
  end
  
end

# Returns the RightScale account number in which the CAT was launched.
define find_account_number() return $rs_account_number do
  $cloud_accounts = to_object(first(rs_cm.cloud_accounts.get()))
  @info = first(rs_cm.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href, "/"))
  #rs_cm.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end

# Get credential
# The credentials API uses a partial match filter so if there are other credentials with this string in their name, they will be returned as well.
# Therefore look through what was returned and find what we really want.
define get_cred($cred_name) return $cred_value do
  @cred = rs_cm.credentials.get(filter: "name=="+$cred_name, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = ""
  foreach $detail in $cred_hash["details"] do
    if $detail["name"] == $cred_name
      $cred_value = $detail["value"]
    end
  end
end
  