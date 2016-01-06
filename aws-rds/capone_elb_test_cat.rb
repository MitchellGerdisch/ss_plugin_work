# This version of the CAT represents Cap1 requirements based on the CFT they provided.

name "Elastic Load Balancer"
rs_ca_ver 20131202
short_description "Allows you to create and manage AWS Elastic Load Balancers like any other CAT resource."

long_description "Create/Delete/List AWS RDSs via an SS Plugin Praxis App server"

#########
# Inputs
#########

# RDS name is constructed from app and env names
#parameter "rds_name" do
#  category "RDS"
#  type "string"
#  label "Application Name"
#  description "What app will this resource be for?"
#  constraint_description "The RDS name must be unique within your set of load balancers for the region, must have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and cannot begin or end with a hyphen."
#  allowed_pattern "(?=[a-zA-Z0-9\-]{1,32}$)^[a-zA-Z0-9]+(\-[a-zA-Z0-9]+)*$"
#end

parameter "param_rds_appname" do
  category "RDS"
  type "string"
  label "Application Name"
  description "What app will this resource be for?"
  default "mitchtest"
end

parameter "param_rds_envtype" do
  category "RDS"
  type "string"
  label "Environment Type"
  description "What environment type is it?"
  allowed_values "test" #only allowing test for now to avoid launching where we shouldn't, "preprod", "prod"
  default "test"
end

parameter "param_rds_owner" do
  category "RDS"
  type "string"
  label "Owner Contact Name"
  description "Who is the contact for or team who created the resource (EID or email)."
  constraint_description "Must be EID or email address."
  allowed_pattern "(^[a-zA-Z0-9\.\-_]+@capitalone\.com$)|(^[a-z]{3}[0-9]+$)"
  default "mrg000"
end

#########
# Mappings
#########
#mapping "map_config" do {
#  # A straight port of the mapping in the provided CFT
#  "CMDBApplicationService" => {
#     "test"=> "ASVEVENTSCHEDULING",
#     "preprod"=> "ASVEVENTSCHEDULING",
#     "prod"=> "ASVEVENTSCHEDULING"
#   },
#   "CMDBEnvironment"=> {
#     "test"=> "ENVNPEVENTSCHEDULING",
#     "preprod"=> "ENVNPEVENTSCHEDULING",
#     "prod"=> "ENVPREVENTSCHEDULING"
#   },
#   "RDSScheme"=> {
#     "test"=> "internal",
#     "preprod"=> "internal",
#     "prod"=> "internal"
#   },
#   "SecurityGroups"=> {
#     "test"=> "sg-e2cf9086",
#     "preprod"=> "sg-37ce9153",
#     "prod"=> "sg-7fdfb41b"
#   },
#   "SNSAppNotifyTopic"=> {
#     "test"=> "arn:aws:sns:us-east-1:084220657940:esa-notify-nonprod",
#     "preprod"=> "arn:aws:sns:us-east-1:084220657940:esa-notify-nonprod",
#     "prod"=> "arn:aws:sns:us-east-1:884541871395:esa-notify-prod"
#   },
#   "SNSOpsNotifyTopic"=> {
#     "test"=> "arn:aws:sns:us-east-1:084220657940:Enterprise_Monitoring_SNS_Retail",
#     "preprod"=> "arn:aws:sns:us-east-1:084220657940:Enterprise_Monitoring_SNS_Retail",
#     "prod"=> "arn:aws:sns:us-east-1:884541871395:Enterprise_Monitoring_SNS_Retailbank"
#   },
#   "Subnets"=> {
#     "test"=> "subnet-05b9c75c,subnet-a9660582",
#     "preprod"=> "subnet-bbb895e2,subnet-b3aaf998,subnet-7948420e",
#     "prod"=> "subnet-c82578e3,subnet-bc3124cb,subnet-4e517e17"
#   }
#} end

# TEST VERSION
mapping "map_config" do {
  "CMDBApplicationService" => {
     "test"=> "ASVEVENTSCHEDULING",
     "preprod"=> "ASVEVENTSCHEDULING",
     "prod"=> "ASVEVENTSCHEDULING"
   },
   "CMDBEnvironment"=> {
     "test"=> "ENVNPEVENTSCHEDULING",
     "preprod"=> "ENVNPEVENTSCHEDULING",
     "prod"=> "ENVPREVENTSCHEDULING"
   },
   "RDSScheme"=> {
     "test"=> "internal",
     "preprod"=> "internal",
     "prod"=> "internal"
   },
   "SecurityGroups"=> {
     "test"=> "sg-66592b00,sg-0b592b6d",
   },
   "SNSAppNotifyTopic"=> {
     "test"=> "arn:aws:sns:us-east-1:084220657940:esa-notify-nonprod",
     "preprod"=> "arn:aws:sns:us-east-1:084220657940:esa-notify-nonprod",
     "prod"=> "arn:aws:sns:us-east-1:884541871395:esa-notify-prod"
   },
   "SNSOpsNotifyTopic"=> {
     "test"=> "arn:aws:sns:us-east-1:084220657940:Enterprise_Monitoring_SNS_Retail",
     "preprod"=> "arn:aws:sns:us-east-1:084220657940:Enterprise_Monitoring_SNS_Retail",
     "prod"=> "arn:aws:sns:us-east-1:884541871395:Enterprise_Monitoring_SNS_Retailbank"
   },
   "Subnets"=> {
     "test"=> "subnet-e237ce94,subnet-1c564545",
   }
} end

#########
# Resources
#########

#resource "rds_listener_http80_http80", type: "rds.listener" do
#  load_balancer @rds
#  lb_protocol  "HTTP"
#  lb__port     "80"
#  instance_protocol "HTTP"
#  instance_port     "80"
#end
#
#resource "rds_listener_http8080_http8080", type: "rds.listener" do
#  load_balancer @rds
#  lb_protocol  "HTTP"
#  lb__port     "8080"
#  instance_protocol "HTTP"
#  instance_port     "8080"
#end

resource "rds", type: "rds.load_balancer" do
  name  join([$param_rds_appname,"-",$param_rds_envtype,"-web-rds"])
  subnets  map($map_config, "Subnets", $param_rds_envtype)
  security_groups map($map_config, "SecurityGroups", $param_rds_envtype)
  healthcheck_target  "HTTP:8080/index.html"
  healthcheck_interval "33"
  healthcheck_timeout "7"
  healthcheck_unhealthy_threshold "6"
  healthcheck_healthy_threshold "4"
  connection_draining_timeout "122" # if null then connection_draining_policy is disabled
  connection_idle_timeout "93"
  cross_zone  "true"
  scheme  "internal"
  listeners do [ # Must have at least one listener defined.
    {
      "listener_name" => "rds_listener_http8080_http8080",
      "lb_protocol" => "HTTP",
      "lb_port" => "8080",
      "instance_protocol" => "HTTP",
      "instance_port" => "8080"
    },
    {
      "listener_name" => "rds_listener_http80_http80",
      "lb_protocol" => "HTTP",
      "lb_port" => "80",
      "instance_protocol" => "HTTP",
      "instance_port" => "80"
    }
  ] end
  tags join(["ASV:",map($map_config, "CMDBApplicationService", $param_rds_envtype)]), join(["CMDBEnvironment:",map($map_config, "CMDBEnvironment", $param_rds_envtype)]), join(["OwnerContact:",$param_rds_owner]), join(["SNSTopicARN:",map($map_config, "SNSAppNotifyTopic", $param_rds_envtype)])
end

#########
# AWS RDS Service
#########
namespace "rds" do
  service do
    host "https://184.73.90.169:8443"        # HTTP endpoint presenting an API defined by self-service to act on resources
                                             # The Praxis server for this is sitting behind a nginx proxy serving HTTPS
    path "/rds"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345",  # Shared secret set up on the Praxis App server providing the RDS plugin service
    } end
  end
  
  
  type "load_balancer" do                       # defines resource of type "load_balancer"
    provision "provision_lb"         # name of RCL definition to use to provision the resource
    delete "delete_lb"               # name of RCL definition to use to delete the resource
    fields do                          
#      field "name" do                               
#        type "string"
#        required true
#      end
      field "subnets" do                               
        type "string"
        required true
      end
      field "security_groups" do                               
        type "string"
        required true
      end
      field "healthcheck_target" do                               
        type "string"
      end
      field "healthcheck_interval" do
        type "string"
      end
      field "healthcheck_timeout" do
        type "string"
      end
      field "healthcheck_unhealthy_threshold" do
        type "string"
      end
      field "healthcheck_healthy_threshold" do
        type "string"
      end
      field "connection_draining_timeout" do
        type "string"
      end
      field "connection_idle_timeout" do
        type "string"
      end
      field "cross_zone" do
        type "string"
      end
      field "scheme" do
        type "string"
      end
      field "listeners" do
        type "composite"
        required true
      end
      field "tags" do
        type "array"
      end
    end
  end
end

# Define the RCL definitions to create and destroy the resource
define provision_lb(@raw_rds) return @rds do
  
#  rs.audit_entries.create(
#    notify: "None",
#    audit_entry: {
#      auditee_href: @@deployment,
#      summary: "raw_rds:",
#      detail: to_s(to_object(@raw_rds))
#    }
#  )
  
  $api_listeners = []
  foreach $listener in @raw_rds.listeners do
    $api_listener = {
      lb_protocol: $listener["lb_protocol"],
      lb_port: $listener["lb_port"],
      instance_protocol: $listener["instance_protocol"],
      instance_port: $listener["instance_port"]
    }
    $api_listeners << $api_listener
  end
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "listeners:",
      detail: to_s($api_listeners)
    }
  )
  
  $api_healthcheck = {
    "target": @raw_rds.healthcheck_target,
    "interval": @raw_rds.healthcheck_interval,
    "timeout": @raw_rds.healthcheck_timeout,
    "unhealthy_threshold": @raw_rds.healthcheck_unhealthy_threshold,
    "healthy_threshold": @raw_rds.healthcheck_healthy_threshold
  }
    
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "healthcheck:",
      detail: to_s($api_healthcheck)
    }
  )
  
  $api_subnets = []
  foreach $api_subnet in split(@raw_rds.subnets, ",") do
    $api_subnets << $api_subnet
  end
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "subnets:",
      detail: to_s($api_subnets)
    }
  )
  
  $api_secgroups = []
  foreach $api_secgroup in split(@raw_rds.security_groups, ",") do
    $api_secgroups << $api_secgroup
  end
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "secgroups:",
      detail: to_s($api_secgroups)
    }
  )
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "tags:",
      detail: to_s(@raw_rds.tags)
    }
  )
  
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
  
  @rds = rds.load_balancer.create({
    name: @raw_rds.name,
    listeners: $api_listeners,
    healthcheck: $api_healthcheck,
    subnets: $api_subnets,
    secgroups: $api_secgroups,
    connection_draining_timeout: @raw_rds.connection_draining_timeout,
    connection_idle_timeout: @raw_rds.connection_idle_timeout,
    cross_zone: @raw_rds.cross_zone,
    scheme: @raw_rds.scheme,
    tags: @raw_rds.tags,
    aws_creds: [$aws_access_key_id, $aws_secret_access_key]
  }) # Calls .create on the API resource
  

end

define delete_lb(@rds) do
  @rds.destroy() # Calls .delete on the API resource
end



#########
# Parameters
#########

#########
# Mappings
#########

#########
# Operation
#########



#########
# RCL
#########

