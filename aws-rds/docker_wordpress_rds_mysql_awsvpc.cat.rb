# Docker WordPress Container with an RDS backend for the DB.
#
# Key Features:
#   Creates an RDS instance using SS plugin
#   Launches a Docker server and a WordPress container on the server which connects to the RDS for the DB.
#   Tags both the Docker Server and RDS Instance with various tags.
#
# TO-DO
# Handle the username and password for the DB access better.
# Add bits to support creating and deleting the RDS security group.


name 'WordPress Container with External RDS DB Server'
rs_ca_ver 20131202
short_description "WordPress Container with External RDS MySQL DB Server"

### Inputs ####
parameter "param_db_username" do 
  category "RDS Configuration Options"
  label "RDS DB User Name" 
  type "string" 
  min_length 1
  max_length 16
  allowed_pattern '^[a-zA-Z].*$'
  no_echo false
end

parameter "param_db_password" do 
  category "RDS Configuration Options"
  label "RDS DB User Password" 
  type "string" 
  min_length 8
  max_length 41
  no_echo true
end

parameter "param_db_size" do 
  category "RDS Configuration Options"
  label "DB Size (GB)" 
  type "number" 
  min_value 5
  max_value 25
  default 5
end

parameter "param_costcenter" do 
  category "Deployment Options"
  label "Budget Code" 
  type "number" 
  min_value 1
  max_value 999999
  default 1164
end

### Security Group Definitions ###
resource "sec_group", type: "security_group" do
  name join(["DockerServerSecGrp-",last(split(@@deployment.href,"/"))])
  description "Docker Server deployment security group."
  cloud 'EC2 us-east-1'
end

resource "sec_group_rule_http", type: "security_group_rule" do
  name "Docker deployment HTTP Rule"
  description "Allow HTTP access."
  source_type "cidr_ips"
  security_group @sec_group
  protocol "tcp"
  direction "ingress"
  cidr_ips "0.0.0.0/0"
  protocol_details do {
    "start_port" => "8080",
    "end_port" => "8080"
  } end
end

resource "sec_group_rule_ssh", type: "security_group_rule" do
  like @sec_group_rule_http

  name "Docker deployment SSH Rule"
  description "Allow SSH access."
  protocol_details do {
    "start_port" => "22",
    "end_port" => "22"
  } end
end  

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @sec_group_rule_http

  name "Docker deployment MySQL Rule"
  description "Allow MySQL access."
  protocol_details do {
    "start_port" => "3306",
    "end_port" => "3306"
  } end
end


### SSH Key ###
resource "ssh_key", type: "ssh_key" do

  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud 'EC2 us-east-1'
end

resource 'wordpress_docker_server', type: 'server' do
  name 'Docker Wordpress'
  cloud 'EC2 us-east-1'
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template find('Docker Technology Demo', revision: 2)
  inputs do {
    'COLLECTD_SERVER' => 'env:RS_SKETCHY',
    'DOCKER_ENVIRONMENT' => 'text:wordpress:
  WORDPRESS_DB_HOST: TBD 
  WORDPRESS_DB_USER: TBD
  WORDPRESS_DB_PASSWORD: TBD
  WORDPRESS_DB_NAME: dwp_rds_db',
    'DOCKER_PROJECT' => 'text:rightscale',
    'DOCKER_SERVICES' => 'text:wordpress:
  image: wordpress
  ports:
    - 8080:80',
    'HOSTNAME' => 'env:RS_SERVER_NAME',
    'NTP_SERVERS' => 'array:["text:time.rightscale.com","text:ec2-us-east.time.rightscale.com","text:ec2-us-west.time.rightscale.com"]',
    'RS_INSTANCE_UUID' => 'env:RS_INSTANCE_UUID',
    'SWAP_FILE' => 'text:/mnt/ephemeral/swapfile',
    'SWAP_SIZE' => 'text:1',
  } end
end

resource "rds", type: "rds.instance" do
  name join(['rds-instance-',last(split(@@deployment.href,"/"))])
  db_name  "dwp_rds_db"
  instance_class "db.m1.small"
  engine "MySQL"
  allocated_storage $param_db_size 
  master_username $param_db_username
  master_user_password $param_db_password
  tags join(["BudgetCode:",$param_costcenter])
end

# Operations
operation "launch" do
    description 'Launch the application' 
    definition 'launch_handler' 
    
    output_mappings do {
      $wordpress_url => $wordpress_link,
      $rds_url => $rds_link,
      $rds_connect_port => $rds_port
    } end
end 

operation "terminate" do
    description 'Terminate the application' 
    definition 'termination_handler' 
end 

operation "RDS Snapshot" do
  description "Creates a snapshot of the RDS DB."
  definition "take_rds_snapshot"
end

########
# RCL
########
define launch_handler(@wordpress_docker_server, @rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql, $param_costcenter, $param_db_username, $param_db_password)  return @wordpress_docker_server, @rds, $rds_link, $rds_port, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql, $wordpress_link do 

  call getLaunchInfo() retrieve $execution_name, $userid, $execution_description
  
  # Set additional tags on RDS
  $rds_addl_tags = ["ExecutionName:"+$execution_name, "Owner:"+$userid, "Description:"+$execution_description]
  $rds_object = to_object(@rds)
  $rds_object["fields"]["tags"] = $rds_object["fields"]["tags"] + $rds_addl_tags
  @rds = $rds_object

  provision(@ssh_key)
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_ssh)
  provision(@sec_group_rule_mysql)

  concurrent return @rds, @wordpress_docker_server do
    provision(@rds)
    provision(@wordpress_docker_server)
  end
  
  $rds_object = to_object(@rds)
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "rds after provision returns:",
      detail: to_s($rds_object)
    }
  )
  
  # configure the docker wordpress environment variables to point at the DB server
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + $rds_object["details"][0]["db_instance_endpoint_address"] + "\n   WORDPRESS_DB_USER: "+ $param_db_username + "\n   WORDPRESS_DB_PASSWORD: " + $param_db_password + "\n   WORDPRESS_DB_NAME: dwp_rds_db"
  $inp = {
    'DOCKER_ENVIRONMENT' => join(["text:", $docker_env])
  } 
  @wordpress_docker_server.current_instance().multi_update_inputs(inputs: $inp) 
  
  # Rerun docker stuff to launch wordpress
  $script_name = "APP docker services compose"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
    
  $script_name = "APP docker services up"
  @script = rs.right_scripts.get(filter: join(["name==",$script_name]))
  $right_script_href=@script.href
  @tasks = @wordpress_docker_server.current_instance().run_executable(right_script_href: $right_script_href, inputs: {})
    
  $wordpress_server_address = @wordpress_docker_server.current_instance().public_ip_addresses[0]
  $wordpress_link = join(["http://",$wordpress_server_address,":8080"])
    
  # Tag the docker server with the required tags.
  $tags=[join(["ec2:BudgetCode=",$param_costcenter]), join(["ec2:ExecutionName=",$execution_name]), join(["ec2:Owner=",$userid]), join(["ec2:Description=",$execution_description])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)

  # Create Credentials with the DB creds
  $deployment_number = last(split(@@deployment.href,"/"))
  $credname = "CAT_RDS_USERNAME_"+$deployment_number
  rs.credentials.create({"name":$credname, "value": $param_db_username})
  $credname = "CAT_RDS_PASSWORD_"+$deployment_number
  rs.credentials.create({"name":$credname, "value": $param_db_password})
    
  # Build the link to show the RDS info in CM.
  # NOTE: As seen in other places in this CAT, the assumption is that the RDS is in AWS US-East-1
  call find_account_number() retrieve $rs_account_number
  $rds_link = join(['https://my.rightscale.com/acct/',$rs_account_number,'/clouds/1/rds_browser?ui_route=instances/rds-instance-',last(split(@@deployment.href,"/")),'/info'])

end

define termination_handler(@wordpress_docker_server, @rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql)  return @wordpress_docker_server, @rds, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql do 

  concurrent return @rds, @wordpress_docker_server do
    delete(@rds)
    delete(@wordpress_docker_server)
  end
  
  delete(@ssh_key)
  delete(@sec_group_rule_http)
  delete(@sec_group_rule_ssh)
  delete(@sec_group_rule_mysql)
  delete(@sec_group)
  
  # Delete the creds we created for the user-provided DB username and password
  $deployment_number = last(split(@@deployment.href,"/"))
  $credname = "CAT_RDS_USERNAME_"+$deployment_number
  @cred=rs.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()
  $credname = "CAT_RDS_PASSWORD_"+$deployment_number
  @cred=rs.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()

end

define take_rds_snapshot() do
  
  # Get the AWS creds and send them to the plugin server to use
  # NOTE: HTTPS is being used to protect the these values.
  call get_cred("AWS_ACCESS_KEY_ID") retrieve $cred_value
  $aws_access_key_id = $cred_value
  
  call get_cred("AWS_SECRET_ACCESS_KEY") retrieve $cred_value
  $aws_secret_access_key = $cred_value
  
  $signature = { 
      type: "aws",
      access_key: $aws_access_key_id,
      secret_key: $aws_secret_access_key
      }
    
  # Keeping track of rds snapshots using a deployment tag
  $rds_snapshot_num = 0
  $tags = rs.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  foreach $tag_item in $tag_array do
    $tag = $tag_item['name']
    if $tag =~ /rds:snapshot/
      $rds_snapshot_num = to_n(split($tag, "=")[1])
    end
  end 
  $rds_snapshot_num = $rds_snapshot_num + 1
  rs.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["rds:snapshotnum=",to_s($rds_snapshot_num)])])

  # Call RDS API directly to do the snapshot
  $rds_instance_id = join(['rds-instance-',last(split(@@deployment.href,"/"))])
  $rds_snapshot_id = join(['rds-snapshot-',last(split(@@deployment.href,"/")),"-",$rds_snapshot_num])
  $response = http_get(
      url: "https://rds.us-east-1.amazonaws.com/?Action=CreateDBSnapshot&DBInstanceIdentifier="+$rds_instance_id+"&DBSnapshotIdentifier="+$rds_snapshot_id,
      signature: $signature
    )
    
    rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "rds snapshot - http response",
      detail: to_s($response)
      }
    )
   
end

#########
# Outputs
#########
output "wordpress_url" do
  label "WordPress Link"
  category "WordPress App Info"
end

output "rds_url" do
  label "RDS Link"
  category "RDS Info"
end

output "rds_connect_port" do
  label "RDS Port"
  category "RDS Info"
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
      field "vpc_security_group_ids" do
        type "string"
      end
      field "master_username" do
        type "string"
      end
      field "master_user_password" do
        type "string"
      end
      field "tags" do
        type "array"
      end
    end
  end
end

# Define the RCL definitions to create and destroy the resource
define provision_db(@raw_rds) return @rds do
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "rds raw object:",
      detail: to_s(to_object(@raw_rds))
    }
  )
  
  # Create Credentials so a user can access the RDS DB if they want.
#  $deployment_number = last(split(@@deployment.href,"/"))
#  $rds_username_cred = "RDS_USERNAME_"+$deployment_number
#  $rds_password_cred = "RDS_PASSWORD_"+$deployment_number
#  call createCreds([$rds_username_cred, $rds_password_cred])
  
  # Pass the username and password to the plugin service as part of the create
  # username and password are hardcoded in the docker env stuff above
#  @cred = rs.credentials.get(filter: "name=="+$rds_username_cred, view: "sensitive") 
#  $cred_hash = to_object(@cred)
#  $cred_value = $cred_hash["details"][0]["value"]
#  $rds_username = $cred_value
#  
#  @cred = rs.credentials.get(filter: "name=="+$rds_password_cred, view: "sensitive") 
#  $cred_hash = to_object(@cred)
#  $cred_value = $cred_hash["details"][0]["value"]
#  $rds_password = $cred_value
  
#  # Array up the security groups
#  $api_secgroups = []
#  foreach $api_secgroup in split(@raw_rds.db_security_groups, ",") do
#    $api_secgroups << $api_secgroup
#  end
  
  # Get the AWS creds and send them to the plugin server to use
  # NOTE: HTTPS is being used to protect the these values.
  call get_cred("AWS_ACCESS_KEY_ID") retrieve $cred_value
  $aws_access_key_id = $cred_value
  
  call get_cred("AWS_SECRET_ACCESS_KEY") retrieve $cred_value
  $aws_secret_access_key = $cred_value
  
  # Get the security group id
  @sg = rs.security_groups.get(filter: [join(["name==DockerServerSecGrp-",last(split(@@deployment.href,"/"))])])
  
  @rds = rds.instance.create({
    db_name: @raw_rds.db_name,
    instance_id: @raw_rds.name,
    instance_class: @raw_rds.instance_class,
    engine: @raw_rds.engine,
    allocated_storage: @raw_rds.allocated_storage,
#    db_security_groups: $api_secgroups,
    vpc_security_group_ids: [to_s(@sg.resource_uid)],
    master_username: @raw_rds.master_username,
    master_user_password: @raw_rds.master_user_password,
    tags: @raw_rds.tags,
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
  $rds_ready = false
  while logic_not($rds_ready) do
    
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
      $rds_ready = true
    else
      sleep(30)
    end
  end
end

define delete_db(@rds) do
  
  # Delete the credentials created for the RDS DB access
#  $deployment_number = last(split(@@deployment.href,"/"))
#  $rds_username_cred = "RDS_USERNAME_"+$deployment_number
#  $rds_password_cred = "RDS_PASSWORD_"+$deployment_number
#  call deleteCreds([$rds_username_cred, $rds_password_cred])
  
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
  $cloud_accounts = to_object(first(rs.cloud_accounts.get()))
  @info = first(rs.cloud_accounts.get())
  $info_links = @info.links
  $rs_account_info = select($info_links, { "rel": "account" })[0]
  $rs_account_href = $rs_account_info["href"]  
    
  $rs_account_number = last(split($rs_account_href, "/"))
  #rs.audit_entries.create(notify: "None", audit_entry: { auditee_href: @deployment, summary: "rs_account_number" , detail: to_s($rs_account_number)})
end

# Get credential
# The credentials API uses a partial match filter so if there are other credentials with this string in their name, they will be returned as well.
# Therefore look through what was returned and find what we really want.
define get_cred($cred_name) return $cred_value do
  @cred = rs.credentials.get(filter: "name=="+$cred_name, view: "sensitive") 
  $cred_hash = to_object(@cred)
  $cred_value = ""
  foreach $detail in $cred_hash["details"] do
    if $detail["name"] == $cred_name
      $cred_value = $detail["value"]
    end
  end
end
  