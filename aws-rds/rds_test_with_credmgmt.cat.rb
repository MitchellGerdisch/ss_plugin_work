# DOESN'T SUPPORT MULTI AVAILABLITY ZONES

name "Relational Database Service (RDS) - with credential management"
rs_ca_ver 20131202
short_description "Allows you to create and manage AWS RDS instances like any other CAT resource."

long_description "Create/Delete/List AWS RDS instances via an SS Plugin Praxis App server"

### Inputs ####
parameter "param_db_size" do 
  category "RDS Configuration Options"
  label "DB Size (GB)" 
  type "number" 
  min_value 5
  max_value 25
  default 5
end


#########
# Resources
#########

resource "rds", type: "rds.instance" do
  name join(['rds-instance-',last(split(@@deployment.href,"/"))])
  db_name  "rds_db"
  instance_class "db.m1.small"
  engine "MySQL"
  allocated_storage $param_db_size 
  db_security_groups "rds-ss-secgroup"
end

operation "launch" do
  description 'Launch the application' 
  definition 'launch_handler' 
  
  output_mappings do {
    $rds_url => $rds_link,
    $rds_connect_port => $rds_port
  } end
end

#########
# Outputs
#########
output "rds_url" do
  label "RDS Link"
  category "Output"
end

output "rds_connect_port" do
  label "RDS Port"
  category "Output"
end

########
# RCL
########
define launch_handler(@rds) return @rds, $rds_link, $rds_port do
  
  provision(@rds)
    
  $rds_object = to_object(@rds)
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "rds after provision returns:",
      detail: to_s($rds_object)
    }
  )
  
  $rds_link = $rds_object["details"][0]["db_instance_endpoint_address"]
  $rds_port = $rds_object["details"][0]["db_instance_endpoint_port"]
end




#########
# AWS RDS Service
#########
namespace "rds" do
  service do
    host "https://184.73.90.169:8443"         # HTTP endpoint presenting an API defined by self-service to act on resources
    path "/rds"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345"  # Shared secret set up on the Praxis App server providing the RDS plugin service
    } end
  end
  
  
  type "instance" do                       # defines resource of type "load_balancer"
    provision "provision_db"         # name of RCL definition to use to provision the resource
    delete "delete_db"               # name of RCL definition to use to delete the resource
    fields do                          
      field "db_name"  do
        type "string"
      end
      field "instance_class" do
        type "string"
      end
      field "engine" do
        type "string"
      end
      field "allocated_storage" do
        type "string"
      end
      field "db_security_groups" do
        type "string"
      end
      field "master_username" do
        type "string"
      end
      field "master_user_password" do
        type "string"
      end
    end
  end
end

# Define the RCL definitions to create and destroy the resource
define provision_db(@raw_rds) return @rds do
  
#  rs.audit_entries.create(
#    notify: "None",
#    audit_entry: {
#      auditee_href: @@deployment,
#      summary: "rds raw object:",
#      detail: to_s(to_object(@raw_rds))
#    }
#  )
  
  # Create Credentials so a user can access the RDS DB if they want.
  $deployment_number = last(split(@@deployment.href,"/"))
  $rds_username_cred = "RDS_USERNAME_"+$deployment_number
  $rds_password_cred = "RDS_PASSWORD_"+$deployment_number
  call createCreds([$rds_username_cred, $rds_password_cred])
  
  # Pass the username and password to the plugin service as part of the create
  @cred = rs.credentials.get(filter: "name=="+$rds_username_cred, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = $cred_hash["details"][0]["value"]
  $rds_username = $cred_value
  
  @cred = rs.credentials.get(filter: "name=="+$rds_password_cred, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = $cred_hash["details"][0]["value"]
  $rds_password = $cred_value
  
  # Array up the security groups
  $api_secgroups = []
  foreach $api_secgroup in split(@raw_rds.db_security_groups, ",") do
    $api_secgroups << $api_secgroup
  end
  
  # Get the AWS creds and send them to the plugin server to use
  # NOTE: HTTPS is being used to protect the these values.
  @cred = rs.credentials.get(filter: "name==AWS_ACCESS_KEY_ID", view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = $cred_hash["details"][0]["value"]
  $aws_access_key_id = $cred_value
  
  @cred = rs.credentials.get(filter: "name==AWS_SECRET_ACCESS_KEY", view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = $cred_hash["details"][0]["value"]
  $aws_secret_access_key = $cred_value
  
  @rds = rds.instance.create({
    db_name: @raw_rds.db_name,
    instance_id: @raw_rds.name,
    instance_class: @raw_rds.instance_class,
    engine: @raw_rds.engine,
    allocated_storage: @raw_rds.allocated_storage,
    db_security_groups: $api_secgroups,
    master_username: $rds_username,
    master_user_password: $rds_password,
    aws_creds: [$aws_access_key_id, $aws_secret_access_key]
  }) # Calls .create on the API resource
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "created rds object:",
      detail: to_s(to_object(@rds))
    }
  )
  
  # Now wait until the RDS is available before returning
  $found_fqdn = false
  while logic_not($found_fqdn) do
    
    @rds = @rds.get()  # refresh the fields for the resource
    $db_instance_status = to_object(@rds)["details"][0]["db_instance_status"]
  
#    rs.audit_entries.create(
#      notify: "None",
#      audit_entry: {
#        auditee_href: @@deployment,
#        summary: "db_instance_status: "+$db_instance_status,
#        detail: ""
#      }
#    )
    
    if $db_instance_status != "creating"  # then it's as ready as it's gonna be
      $found_fqdn = true
    else
      sleep(30)
    end
  end
end

define delete_db(@rds) do
  
  # Delete the credentials created for the RDS DB access
  $deployment_number = last(split(@@deployment.href,"/"))
  $rds_username_cred = "RDS_USERNAME_"+$deployment_number
  $rds_password_cred = "RDS_PASSWORD_"+$deployment_number
  call deleteCreds([$rds_username_cred, $rds_password_cred])
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "deleting rds: "+to_s(@rds),
      detail: to_s(to_object(@rds))
    }
  )
  
  @rds.destroy() # Calls .delete on the API resource
end


#######
# Helper Functions
#######
# Creates CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define createCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
    if empty?(@cred) 
      $cred_value = join(split(uuid(), "-"))[0..14] # max of 16 characters for mysql username and we're adding a letter next.
      $cred_value = "a" + $cred_value # add an alpha to the beginning of the value - just in case.
      @task=rs.credentials.create({"name":$cred_name, "value": $cred_value})
    end
  end
end

# Deletes CREDENTIAL objects in Cloud Management for each of the named items in the given array.
define deleteCreds($credname_array) do
  foreach $cred_name in $credname_array do
    @cred = rs.credentials.get(filter: join(["name==",$cred_name]))
#    rs.audit_entries.create(
#      notify: "None",
#      audit_entry: {
#        auditee_href: @@deployment,
#        summary: "cred name: "+$cred_name+" - "+to_s(@cred),
#        detail: ""
#      }
#    )
    if logic_not(empty?(@cred))
#      rs.audit_entries.create(
#        notify: "None",
#        audit_entry: {
#          auditee_href: @@deployment,
#          summary: "Deleting cred: "+to_s(@cred),
#          detail: ""
#        }
#      )
      @cred.destroy()
    end
  end
end

