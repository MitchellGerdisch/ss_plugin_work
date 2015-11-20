# This version of the CAT represents Cap1 requirements based on the CFT they provided.

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
  default "testapp"
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
  allowed_pattern "(^[a-zA-Z0-9\.\-_]+@capitalone\.com$)|(^[a-z]{3}[0-9]+$)"
  default "mrg000"
end

#########
# Mappings
#########
mapping "map_config" do {
  # A straight port of the mapping in the provided CFT
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
     "test"=> "sg-e2cf9086",
     "preprod"=> "sg-37ce9153",
     "prod"=> "sg-7fdfb41b"
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
     "test"=> "subnet-05b9c75c,subnet-a9660582"
     "preprod"=> "subnet-bbb895e2,subnet-b3aaf998,subnet-7948420e"
     "prod"=> "subnet-c82578e3,subnet-bc3124cb,subnet-4e517e17"
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
  name  join([$elb_appname,"-",$param_elb_envtype,"-web-elb"])
  subnets  map($map_config, "Subnets", $param_elb_envtype)
  security_groups map($map_config, "SecurityGroups", $param_elb_envtype)
  healthcheck_target  "TCP:8080/index.html"
  healthcheck_interval "30"
  healthcheck_timeout "5"
  healthcheck_unhealthy_threshold "5"
  healthcheck_healthy_threshold "3"
  connection_draining_timeout "120" # if null then connection_draining_policy is disabled
  connection_idle_timeout "90"
  cross_zone  "true"
  scheme  "internal"
  listeners do [
    {
      "listener_name" => "elb_listener_http8080_http8080",
      "lb_protocol" => "HTTP",
      "lb__port" => "8080",
      "instance_protocol" => "HTTP",
      "instance_port" => "8080"
    },
    {
      "listener_name" => "elb_listener_http80_http80",
      "lb_protocol" => "HTTP",
      "lb__port" => "80",
      "instance_protocol" => "HTTP",
      "instance_port" => "80"
    }
  ] end
# TODO add tagging stuff
#  tags  $tags  
end

#########
# AWS ELB Service
#########
namespace "elb" do
  service do
    host "184.73.90.169:8888"        # HTTP endpoint presenting an API defined by self-service to act on resources
    path "/elb"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345"  # Shared secret set up on the Praxis App server providing the ELB plugin service
    } end
  end
  
#  type "listener" do
#    provision "provision_listener"  # listeners drive LB creation
#    delete "delete_listener"
#    fields do
#      field "load_balancer" do
#        type "resource"
#        required true
#      end
#      field "lb_protocol" do
#        type "string"
#        required true
#      end
#      field "lb__port" do
#        type "string"
#        required true
#      end
#      field "instance_protocol" do
#        type "string"
#        required true
#      end
#      field "instance_port" do
#        type "string"
#        required true
#      end
#    end
#  end
  
  type "load_balancer" do                       # defines resource of type "load_balancer"
    provision "provision_lb"         # name of RCL definition to use to provision the resource
    delete "delete_lb"               # name of RCL definition to use to delete the resource
    fields do                          
      field "name" do                               
        type "string"
        required true
      end
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
    end
  end
end

# Define the RCL definitions to create and destroy the resource
define provision_lb(@raw_elb) return @elb do
  
  $listeners = 
  @elb = elb.load_balancer.create({
    name: @raw_elb.name,
    lb_listener: {protocol: @raw_elb.lb_listener_protocol, port: @raw_elb.lb_listener_port},
    instance_listener: {protocol: @raw_elb.instance_listener_protocol, port: @raw_elb.instance_listener_port},
    availability_zones: @raw_elb.availability_zones
  }) # Calls .create on the API resource
  
  rs.audit_entries.create(
    notify: "None",
    audit_entry: {
      auditee_href: @@deployment,
      summary: "listener:",
      detail: to_s(@elb)
    }
  )
end

define delete_elb(@elb) do
#  @elb.destroy() # Calls .delete on the API resource
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

