
name "Elastic Load Balancer"
rs_ca_ver 20131202
short_description "Allows you to create and manage AWS Elastic Load Balancers like any other CAT resource."

long_description "Create/Delete/List AWS ELBs via an SS Plugin Praxis App server"

#########
# Inputs
#########

# ELB name is constructed from app and env names
#parameter "elb_name" do
#  category "ELB"
#  type "string"
#  label "Application Name"
#  description "What app will this resource be for?"
#  constraint_description "The ELB name must be unique within your set of load balancers for the region, must have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and cannot begin or end with a hyphen."
#  allowed_pattern "(?=[a-zA-Z0-9\-]{1,32}$)^[a-zA-Z0-9]+(\-[a-zA-Z0-9]+)*$"
#end

parameter "param_elb_appname" do
  category "ELB"
  type "string"
  label "Application Name"
  description "What app will this resource be for?"
  default "mitchtest"
end

parameter "param_elb_envtype" do
  category "ELB"
  type "string"
  label "Environment Type"
  description "What environment type is it?"
  allowed_values "test" #only allowing test for now to avoid launching where we shouldn't, "preprod", "prod"
  default "test"
end

parameter "param_elb_owner" do
  category "ELB"
  type "string"
  label "Owner Contact Name"
  description "Who is the contact for or team who created the resource (EID or email)."
  constraint_description "Must be EID or email address."
  allowed_pattern "(^[a-zA-Z0-9\.\-_]+@example\.com$)|(^[a-z]{3}[0-9]+$)"
  default "mrg000"
end

#########
# Mappings
#########

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
   "ELBScheme"=> {
     "test"=> "internal",
     "preprod"=> "internal",
     "prod"=> "internal"
   },
   "SecurityGroups"=> {
     "test"=> "sg-66592b00,sg-0b592b6d",
   },
   "SNSAppNotifyTopic"=> {
     "test"=> "arn:aws:sns:us-east-1:0842206540:esa-notify-nonprod",
     "preprod"=> "arn:aws:sns:us-east-1:0842206540:esa-notify-nonprod",
     "prod"=> "arn:aws:sns:us-east-1:8845418795:esa-notify-prod"
   },
   "SNSOpsNotifyTopic"=> {
     "test"=> "arn:aws:sns:us-east-1:0842206570:Enterprise_Monitoring_SNS_Retail",
     "preprod"=> "arn:aws:sns:us-east-1:0842206570:Enterprise_Monitoring_SNS_Retail",
     "prod"=> "arn:aws:sns:us-east-1:8845418715:Enterprise_Monitoring_SNS_Retailbank"
   },
   "Subnets"=> {
     "test"=> "subnet-e237ce94,subnet-1c564545",
   }
} end

#########
# Resources
#########

#resource "elb_listener_http80_http80", type: "elb.listener" do
#  load_balancer @elb
#  lb_protocol  "HTTP"
#  lb__port     "80"
#  instance_protocol "HTTP"
#  instance_port     "80"
#end
#
#resource "elb_listener_http8080_http8080", type: "elb.listener" do
#  load_balancer @elb
#  lb_protocol  "HTTP"
#  lb__port     "8080"
#  instance_protocol "HTTP"
#  instance_port     "8080"
#end

resource "elb", type: "elb.load_balancer" do
  name  join([$param_elb_appname,"-",$param_elb_envtype,"-web-elb"])
  subnets  map($map_config, "Subnets", $param_elb_envtype)
  security_groups map($map_config, "SecurityGroups", $param_elb_envtype)
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
      "listener_name" => "elb_listener_http8080_http8080",
      "lb_protocol" => "HTTP",
      "lb_port" => "8080",
      "instance_protocol" => "HTTP",
      "instance_port" => "8080"
    },
    {
      "listener_name" => "elb_listener_http80_http80",
      "lb_protocol" => "HTTP",
      "lb_port" => "80",
      "instance_protocol" => "HTTP",
      "instance_port" => "80"
    }
  ] end
  tags join(["ASV:",map($map_config, "CMDBApplicationService", $param_elb_envtype)]), join(["CMDBEnvironment:",map($map_config, "CMDBEnvironment", $param_elb_envtype)]), join(["OwnerContact:",$param_elb_owner]), join(["SNSTopicARN:",map($map_config, "SNSAppNotifyTopic", $param_elb_envtype)])
end

#########
# AWS ELB Service
#########
namespace "elb" do
  service do
    host "https://184.73.90.169:8443"        # HTTP endpoint presenting an API defined by self-service to act on resources
                                             # The Praxis server for this is sitting behind a nginx proxy serving HTTPS
    path "/elb"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345",  # Shared secret set up on the Praxis App server providing the ELB plugin service
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
define provision_lb(@raw_elb) return @elb do
  
#  rs.audit_entries.create(
#    notify: "None",
#    audit_entry: {
#      auditee_href: @@deployment,
#      summary: "raw_elb:",
#      detail: to_s(to_object(@raw_elb))
#    }
#  )
  
  $api_listeners = []
  foreach $listener in @raw_elb.listeners do
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
    "target": @raw_elb.healthcheck_target,
    "interval": @raw_elb.healthcheck_interval,
    "timeout": @raw_elb.healthcheck_timeout,
    "unhealthy_threshold": @raw_elb.healthcheck_unhealthy_threshold,
    "healthy_threshold": @raw_elb.healthcheck_healthy_threshold
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
  foreach $api_subnet in split(@raw_elb.subnets, ",") do
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
  foreach $api_secgroup in split(@raw_elb.security_groups, ",") do
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
      detail: to_s(@raw_elb.tags)
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
  
  @elb = elb.load_balancer.create({
    name: @raw_elb.name,
    listeners: $api_listeners,
    healthcheck: $api_healthcheck,
    subnets: $api_subnets,
    secgroups: $api_secgroups,
    connection_draining_timeout: @raw_elb.connection_draining_timeout,
    connection_idle_timeout: @raw_elb.connection_idle_timeout,
    cross_zone: @raw_elb.cross_zone,
    scheme: @raw_elb.scheme,
    tags: @raw_elb.tags,
    aws_creds: [$aws_access_key_id, $aws_secret_access_key]
  }) # Calls .create on the API resource
  

end

define delete_lb(@elb) do
  @elb.destroy() # Calls .delete on the API resource
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

