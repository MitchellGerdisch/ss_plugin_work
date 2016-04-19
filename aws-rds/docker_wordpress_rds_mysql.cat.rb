# TO-DO
# Handle the username and password for the DB access better.
# Add bits to support creating and deleting the RDS security group.
# Add tagging for the RDS instance too.


name 'WordPress Container with External RDS DB Server'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) ![logo](https://s3.amazonaws.com/rs-pft/cat-logos/amazon_rds_glossy.png)

WordPress Container with External RDS DB Server"

### Inputs ####
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
  label "Cost Center Tag" 
  type "string" 
  allowed_values "Development", "QA", "Production"
  default "Development"
end

### Security Group Definitions ###
resource "sec_group", type: "security_group" do
  name join(["DockerServerSecGrp-",@@deployment.href])
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
  name 'Docker Wordpress'
  cloud 'EC2 us-east-1'
  ssh_key_href @ssh_key
  security_group_hrefs @sec_group
  server_template find('Docker Technology Demo', revision: 2)
  inputs do {
    'COLLECTD_SERVER' => 'env:RS_SKETCHY',
    'DOCKER_ENVIRONMENT' => 'text:wordpress:
  WORDPRESS_DB_HOST: TBD 
  WORDPRESS_DB_USER: wordpressdbuser
  WORDPRESS_DB_PASSWORD: wordpressdbpassword
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
  db_security_groups "rds-ss-secgroup"  # CURRENTLY THIS NEEDS TO BE PREDEFINED AND SHOULD ALLOW INTERNET ACCESS FOR TESTING
  master_username "wordpressdbuser"
  master_user_password "wordpressdbpassword"
  tags join(["costcenter:",$param_costcenter]),"test:tag2"
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

########
# RCL
########
define launch_handler(@wordpress_docker_server, @rds, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, $param_costcenter)  return @wordpress_docker_server, @rds, $rds_link, $rds_port, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, $wordpress_link do 

  provision(@ssh_key)
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_ssh)

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

  $rds_link = $rds_object["details"][0]["db_instance_endpoint_address"]
  $rds_port = $rds_object["details"][0]["db_instance_endpoint_port"]
  
  # configure the docker wordpress environment variables to point at the DB server
  $db_host_ip = $rds_link
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + $rds_link + "\n   WORDPRESS_DB_USER: wordpressdbuser\n   WORDPRESS_DB_PASSWORD: wordpressdbpassword\n   WORDPRESS_DB_NAME: dwp_rds_db"
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
    
  # Tag the docker server with the selected project cost center ID.
  $tags=[join(["ec2:costcenter=",$param_costcenter])]
  rs.tags.multi_add(resource_hrefs: @@deployment.servers().current_instance().href[], tags: $tags)

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
  
  # Array up the security groups
  $api_secgroups = []
  foreach $api_secgroup in split(@raw_rds.db_security_groups, ",") do
    $api_secgroups << $api_secgroup
  end
  
  # Array up the tags
  $api_tags = []
  foreach $api_tag in @raw_rds.tags do
    rs.audit_entries.create(
      notify: "None",
      audit_entry: {
        auditee_href: @@deployment,
        summary: "api_tag: "+$api_tag,
        detail: ""
      }
    )
    $split_tag = split($api_tag, ":")
    $tag_hash = { "key":$split_tag[0], "value":$split_tag[1] }
    $api_tags << $tag_hash
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
    master_username: @raw_rds.master_username,
    master_user_password: @raw_rds.master_user_password,
    tags: $api_tags,
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