# DOESN'T SUPPORT MULTI AVAILABLITY ZONES

name "Relational Database Service (RDS) - basic"
rs_ca_ver 20131202
short_description "Allows you to create and manage AWS RDS instances like any other CAT resource."

long_description "Create/Delete/List AWS RDS instances via an SS Plugin Praxis App server"


#########
# Resources
#########

resource "rds", type: "rds.instance" do
  name join(['rds-instance-',last(split(@@deployment.href,"/"))])
  db_name  "rds_db"
#  instance_id "mitch-plugin-cat-1"
  instance_class "db.m1.small"
  engine "MySQL"
  allocated_storage "5"
  master_username "mitchsqluser"
  master_user_password "mitchsqlpassword"
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

