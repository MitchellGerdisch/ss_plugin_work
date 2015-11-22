# DOESN'T SUPPORT MULTI AVAILABLITY ZONES

name "Elastic Load Balancer - basic"
rs_ca_ver 20131202
short_description "Allows you to create and manage AWS Elastic Load Balancers like any other CAT resource."

long_description "Create/Delete/List AWS ELBs via an SS Plugin Praxis App server"

#########
# Inputs
#########
parameter "elb_name" do
  type "string"
  label "ELB Name"
  category "ELB"
  constraint_description "The ELB name must be unique within your set of load balancers for the region, must have a maximum of 32 characters, must contain only alphanumeric characters or hyphens, and cannot begin or end with a hyphen."
  allowed_pattern "(?=[a-zA-Z0-9\-]{1,32}$)^[a-zA-Z0-9]+(\-[a-zA-Z0-9]+)*$"
end

parameter "lb_protocol" do
  category "ELB"
  label "Load Balancer Listener Protocol"
  type "string"
  allowed_values "HTTP", "HTTPS", "TCP", "SSL"
  default "HTTP"
end

parameter "lb_port" do
  category "ELB"
  label "Load Balancer Listener Port"
  type "string"
  default "80"
  constraint_description "ELB listener port is restricted to ports 25, 80, 443, 465, 587, or 1024-65535"
  allowed_pattern "^(25|80|443|465|587)$|^(102[4-9])$|^(10[3-9][0-9])$|^(1[1-9][0-9][0-9])$|^([2-9][0-9][0-9][0-9])$|^([1-5][0-9][0-9][0-9][0-9])$|^(6[0-4][0-9][0-9][0-9])$|^(65[0-4][0-9][0-9])$|^(655[0-2][0-9])$|^(6553[0-5])$"
end

parameter "instance_protocol" do
  category "ELB"
  label "Backend Instances' Listening Protocol"
  type "string"
  allowed_values "HTTP", "HTTPS", "TCP", "SSL"
  default "HTTP"
end

parameter "instance_port" do
  category "ELB"
  label "Backend Instances' Listening Port"
  type "string"
  default "8080"
end

parameter "availability_zones" do
  category "ELB"
  label "Availability Zones"
  type "list"
  default "us-east-1a"
end


#########
# Resources
#########

resource "elb", type: "elb.load_balancer" do
  name                  $elb_name
  availability_zones  $availability_zones
  listeners do [ # Must have at least one listener defined.
    {
      "listener_name" => "elb_listener_http8080_http8080",
      "lb_protocol" => $lb_protocol,
      "lb_port" => $lb_port,
      "instance_protocol" => $instance_protocol,
      "instance_port" => $instance_port
    }
  ] end
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
      end
      field "availability_zones" do
        type "array"
      end
      field "security_groups" do                               
        type "string"
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
  
#  rs.audit_entries.create(
#    notify: "None",
#    audit_entry: {
#      auditee_href: @@deployment,
#      summary: "listeners:",
#      detail: to_s($api_listeners)
#    }
#  )
  

  
  @elb = elb.load_balancer.create({
    name: @raw_elb.name,
    availability_zones: @raw_elb.availability_zones,
    listeners: $api_listeners
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

