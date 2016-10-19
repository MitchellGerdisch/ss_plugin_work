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


name 'WordPress Container with External RDS DB Server - V2'
rs_ca_ver 20160622
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) ![logo](https://s3.amazonaws.com/rs-pft/cat-logos/amazon_rds_glossy.png) 

WordPress Container with External RDS MySQL DB Server"

import "utilities"

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


### SSH Key ###
resource "ssh_key", type: "ssh_key" do
  name join(["sshkey_", last(split(@@deployment.href,"/"))])
  cloud 'EC2 us-east-1'
end

resource 'wordpress_docker_server', type: 'server' do
  name join(["DockerHost-", last(split(@@deployment.href,"/"))])
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

resource "my_rds", type: "rds.instances" do
  name join(['rds-instance-',last(split(@@deployment.href,"/"))])
  db_name  "dwp_rds_db"
  instance_class "db.m1.small"
  engine "MySQL"
  allocated_storage $param_db_size 
  db_security_groups "rds-ss-secgroup"  # CURRENTLY THIS NEEDS TO BE PRECONFIGURED AND ALLOW 0.0.0.0/0 ACCESS
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
    } end
end 

operation "terminate" do
    description 'Terminate the application' 
    definition 'termination_handler' 
end 

operation "rds_snapshot" do
  label "RDS Snapshot"
  description "Creates a snapshot of the RDS DB."
  definition "take_rds_snapshot"
end

########
# RCL
########
define launch_handler(@wordpress_docker_server, @my_rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, $param_costcenter, $param_db_username, $param_db_password)  return @wordpress_docker_server, @my_rds, $rds_link, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group, $wordpress_link do 

  call utilities.getLaunchInfo() retrieve $execution_name, $userid, $execution_description
  
  # Set additional tags on RDS
  $rds_addl_tags = ["ExecutionName:"+$execution_name, "Owner:"+$userid, "Description:"+$execution_description]
  $rds_object = to_object(@my_rds)
  $rds_object["fields"]["tags"] = $rds_object["fields"]["tags"] + $rds_addl_tags
  @my_rds = $rds_object

  provision(@ssh_key)
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_ssh)
  provision(@sec_group)

  concurrent return @my_rds, @wordpress_docker_server do
    provision(@my_rds)
    provision(@wordpress_docker_server)
  end
    
  call utilities.log("rds after provision returns:", to_s(to_object(@my_rds)))
  call utilities.log("docker host after provision returns:", to_s(to_object(@wordpress_docker_server)))

  # configure the docker wordpress environment variables to point at the DB server
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + to_s(@my_rds.db_instance_endpoint_address) + "\n   WORDPRESS_DB_USER: "+ $param_db_username + "\n   WORDPRESS_DB_PASSWORD: " + $param_db_password + "\n   WORDPRESS_DB_NAME: dwp_rds_db"
  $inp = {
    'DOCKER_ENVIRONMENT' => join(["text:", $docker_env])
  } 
  @wordpress_docker_server.current_instance().multi_update_inputs(inputs: $inp) 
  
  # Rerun docker stuff to launch wordpress
  call utilities.run_script_by_name(@wordpress_docker_server, "APP docker services compose")
  call utilities.run_script_by_name(@wordpress_docker_server, "APP docker services up")
    
  $wordpress_server_address = @wordpress_docker_server.current_instance().public_ip_addresses[0]
  $wordpress_link = join(["http://",$wordpress_server_address,":8080"])
    
  # Tag the docker server with the required tags.
  $tags=[join(["ec2:BudgetCode=",$param_costcenter]), join(["ec2:ExecutionName=",$execution_name]), join(["ec2:Owner=",$userid]), join(["ec2:Description=",$execution_description])]
  rs_cm.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)

  # Create Credentials with the DB creds
  $deployment_number = last(split(@@deployment.href,"/"))
  $credname = "CAT_RDS_USERNAME_"+$deployment_number
  rs_cm.credentials.create({"name":$credname, "value": $param_db_username})
  $credname = "CAT_RDS_PASSWORD_"+$deployment_number
  rs_cm.credentials.create({"name":$credname, "value": $param_db_password})
    
  # Build the link to show the RDS info in CM.
  # NOTE: As seen in other places in this CAT, the assumption is that the RDS is in AWS US-East-1
  call utilities.find_account_number() retrieve $rs_account_number
  $rds_link = join(['https://my.rightscale.com/acct/',$rs_account_number,'/clouds/1/rds_browser?ui_route=instances/rds-instance-',last(split(@@deployment.href,"/")),'/info'])

end

define termination_handler(@wordpress_docker_server, @my_rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh)  return @wordpress_docker_server, @my_rds, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group do 

  concurrent return @my_rds, @wordpress_docker_server do
    delete(@my_rds)
    delete(@wordpress_docker_server)
  end
  
  concurrent return @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh do
    delete(@ssh_key)
    delete(@sec_group_rule_http)
    delete(@sec_group_rule_ssh)
  end
  
  delete(@sec_group)

  # Delete the creds we created for the user-provided DB username and password
  $deployment_number = last(split(@@deployment.href,"/"))
  $credname = "CAT_RDS_USERNAME_"+$deployment_number
  @cred=rs_cm.credentials.get(filter: [join(["name==",$credname])])
  @cred.destroy()
  $credname = "CAT_RDS_PASSWORD_"+$deployment_number
  @cred=rs_cm.credentials.get(filter: [join(["name==",$credname])])
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
  $tags = rs_cm.tags.by_resource(resource_hrefs: [@@deployment.href])
  $tag_array = $tags[0][0]['tags']
  foreach $tag_item in $tag_array do
    $tag = $tag_item['name']
    if $tag =~ /rds:snapshot/
      $rds_snapshot_num = split($tag, "=")[1]
    end
  end 
  $rds_snapshot_num = $rds_snapshot_num + 1
  rs_cm.tags.multi_add(resource_hrefs: [@@deployment.href], tags: [join(["rds:snapshotnum=",$rds_snapshot_num])])

  # Call RDS API directly to do the snapshot
  $rds_instance_id = join(['rds-instance-',last(split(@@deployment.href,"/"))])
  $rds_snapshot_id = join(['rds-snapshot-',last(split(@@deployment.href,"/")),"-",$rds_snapshot_num])
  $response = http_get(
      url: "https://rds.us-east-1.amazonaws.com/?Action=CreateDBSnapshot&DBInstanceIdentifier="+$rds_instance_id+"&DBSnapshotIdentifier="+$rds_snapshot_id,
      signature: $signature
    )
    
   call utilities.log("rds snapshot - http response", to_s($response))

   
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

#########
# AWS RDS Service
#########
namespace "rds" do
  plugin $rds
  
  parameter_values do
    placeholder "nothing"
  end
end



plugin "rds" do
  endpoint do
    default_scheme "http"
    default_host "184.73.90.169:8080"         # HTTP endpoint presenting an API defined by self-service to act on resources
#    default_host "184.73.90.169:8443"         # HTTP endpoint presenting an API defined by self-service to act on resources
    path "/rds"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345"  # Shared secret set up on the Praxis App server providing the RDS plugin service
    } end
#    no_cert_check true
  end
  
  parameter "placeholder" do
    label "placeholder"
    type "string"
    description "A required placeholder parameter for now"
  end
  
  type "instances" do                       # defines resource of type "load_balancer"
    
#    href_templates "/instances/:db_instance_name:"
    
    provision "provision_db"         # name of RCL definition to use to provision the resource
    
    delete "delete_db"               # name of RCL definition to use to delete the resource
    
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
    field "tags" do
      type "array"
    end
        
    output "db_instance_name","db_name","db_instance_endpoint_address","db_instance_endpoint_port","db_instance_status"
  end
  
end

# Define the RCL definitions to create and destroy the resource
define provision_db(@raw_rds) return @my_rds do
  
  call utilities.log("rds raw object", to_s(to_object(@raw_rds)))
  
  # Array up the security groups
  $api_secgroups = []
  foreach $api_secgroup in split(@raw_rds.db_security_groups, ",") do
    $api_secgroups << $api_secgroup
  end
  
  # Create the RDS service
  @my_rds = rds.instances.create({
    db_name: @raw_rds.db_name,
    instance_id: @raw_rds.name,
    instance_class: @raw_rds.instance_class,
    engine: @raw_rds.engine,
    allocated_storage: @raw_rds.allocated_storage,
    db_security_groups: $api_secgroups,
    master_username: @raw_rds.master_username,
    master_user_password: @raw_rds.master_user_password,
    tags: @raw_rds.tags
#    aws_creds: [$aws_access_key_id, $aws_secret_access_key]
  }) # Calls .create on the API resource
  
  
  call utilities.log("created rds object", to_s(to_object(@my_rds)))
  
#  @my_rds = @my_rds.get()
#  
#  call utilities.log("getted rds object:", to_s(to_object(@my_rds)))
  
  sleep_until(equals?(@my_rds.db_instance_status,"available"))

end

define delete_db(@rds) do
  
  # Delete the credentials created for the RDS DB access
  call utilities.log("deleting rds: "+to_s(@my_rds), to_s(to_object(@my_rds)))

  @rds.destroy() # Calls .delete on the API resource
end
