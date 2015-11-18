name "Elastic Load Balancer"
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
end

parameter "lb_protocol" do
  category "ELB"
  label "Load Balancer Listener Protocol"
  type "string"
  allowed_values "HTTP", "HTTPS", "TCP", "SSL"
  default_value "HTTP"
end

parameter "lb_port" do
  category "ELB"
  label "Load Balancer Listener Port"
  type "number"
  default "80"
end

parameter "instance_protocol" do
  category "ELB"
  label "Instance Protocol"
  type "string"
  allowed_values "HTTP", "HTTPS", "TCP", "SSL"
end

parameter "instance_port" do
  category "ELB"
  label "Instances Port"
  type "number"
  default "8080"
end

parameter "availability_zones" do
  category "ELB"
  label "Instances Port"
  type "list"
  default "us-east-1a"
end


#########
# Resources
#########

resource "elb", type: "elb.load_balancer" do
  name                  $elb_name
  lb_listener_protocol  $lb_protocol
  lb_listener_port      $lb_port
  instance_listener_protocol  $instance_protocol
  instance_listener_port  $instance_port
  availability_zones  "us-east-1a"
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
  type "load_balancer" do                       # defines resource of type "droplet"
    provision "provision_elb"         # name of RCL definition to use to provision the resource
    delete "delete_elb"               # name of RCL definition to use to delete the resource
    fields do                             # field of a droplet with rules for validation
      field "name" do                               
        type "string"
        required true
      end
      field "lb_listener_protocol" do                               
        type "string"
        required true
      end
      field "lb_listener_port" do                               
        type "number"
        required true
      end
      field "instance_listener_protocol" do                               
        type "string"
        required true
      end
      field "instance_listener_port" do                               
        type "number"
        required true
      end
      field "availability_zones" do                               
        type "array"
        required true
      end
    end
  end
end

# Define the RCL definitions to create and destroy the resource
define provision_elb(@raw_elb) return @elb do
  @elb = elb.load_balancer.create({
    name: @raw_elb.name,
    lb_listener: {protocol: @raw_elb.lb_listener_protocol, port: @raw_elb.lb_listener_port},
    instance_listener: {protocol: @raw_elb.instance_listener_protocol, port: @raw_elb.instance_listener_port},
    availability_zones: @raw_elb.availability_zones
  }) # Calls .create on the API resource
  
#rs.audit_entries.create(
#    notify: "None",
#    audit_entry: {
#      auditee_href: @@deployment,
#      summary: "$elb output",
#      detail: to_s(@elb)
#    }
#  )
end

define delete_elb(@elb) do
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

