# TO-DO
# Add resources for SSH key and SecGroup
# Add code to set the WORDPRESS env variable to point at the PUBLIC IP of the MySQL server


name 'WordPress Container with External RDS DB Server'
rs_ca_ver 20131202
short_description "![logo](https://s3.amazonaws.com/rs-pft/cat-logos/docker.png) (http://www.showslow.com/blog/wp-content/uploads/2013/05/amazon_rds_glossy.png)

WordPress Container with External RDS DB Server"

output "wordpress_url" do
  label "WordPress Link"
  category "Output"
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
  WORDPRESS_DB_NAME: app_test',
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
  db_name  "dwp_db"
#  instance_id "mitch-plugin-cat-1"
  instance_class "db.m1.small"
  engine "MySQL"
  allocated_storage "5"
  master_username "mitchsqluser"
  master_user_password "mitchsqlpassword"
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

resource "sec_group_rule_mysql", type: "security_group_rule" do
  like @sec_group_rule_http

  name "Docker deployment SSH Rule"
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


# Operations
operation 'launch' do 
  description 'Launch the application' 
  definition 'generated_launch' 
  
  output_mappings do {
    $wordpress_url => $wordpress_link
  } end
end 

define generated_launch(@wordpress_docker_server, @db_server, @ssh_key, @sec_group, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql)  return @wordpress_docker_server, @db_server, @ssh_key, @sec_group_rule_http, @sec_group_rule_ssh, @sec_group_rule_mysql, $wordpress_link do 
  
  provision(@ssh_key)
  provision(@sec_group_rule_http)
  provision(@sec_group_rule_mysql)
  provision(@sec_group_rule_ssh)
  
  call createCreds(["CAT_MYSQL_ROOT_PASSWORD","CAT_MYSQL_APP_PASSWORD","CAT_MYSQL_APP_USERNAME"])


  concurrent return @db_server, @wordpress_docker_server do
    provision(@db_server)
    provision(@wordpress_docker_server)
  end
  
  # configure the docker wordpress environment variables to point at the DB server
  $db_host_ip = @db_server.current_instance().public_ip_addresses[0]
  $docker_env = "wordpress:\n   WORDPRESS_DB_HOST: " + $db_host_ip + "\n   WORDPRESS_DB_USER: wordpressdbuser\n   WORDPRESS_DB_PASSWORD: wordpressdbpassword\n   WORDPRESS_DB_NAME: app_test"
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

end

########
# Helper Functions
########


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


#########
# AWS RDS Service Namespace
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
#      field "name" do                               
#        type "string"
#        required true
#      end
      
      field "db_name"  do
        type "string"
      end
#      field "instance_id" do
#        type "string"
#      end
      field "instance_class" do
        type "string"
      end
      field "engine" do
        type "string"
      end
      field "allocated_storage" do
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
  
  @rds = rds.instance.create({
    db_name: @raw_rds.db_name,
    instance_id: @raw_rds.name,
    instance_class: @raw_rds.instance_class,
    engine: @raw_rds.engine,
    allocated_storage: @raw_rds.allocated_storage,
    master_username: @raw_rds.master_username,
    master_user_password: @raw_rds.master_user_password
  }) # Calls .create on the API resource
  

end

define delete_db(@rds) do
  @rds.destroy() # Calls .delete on the API resource
end