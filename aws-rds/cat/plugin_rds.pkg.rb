# RDS Plugin Package


name 'Plugin - RDS'
rs_ca_ver 20160622
short_description "RDS Plugin"

package "plugin_rds"
import "utilities"

### Plugin Definition ###
plugin "rds" do
  endpoint do
    default_scheme "http"
    default_host "184.73.90.169:8080"         # HTTP endpoint presenting an API defined by self-service to act on resources
    path "/rds"           # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "12345"  # Shared secret set up on the Praxis App server providing the RDS plugin service
    } end
  end
  
  type "instances" do                       # defines resource of type "load_balancer"
        
    provision "provision_db"         # name of RCL definition to use to provision the resource
    
    delete "delete_db"               # name of RCL definition to use to delete the resource
    
    # Declaration attributes.
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
        
    # Instance attributes returned by the service.
    output "db_instance_name","db_name","db_instance_endpoint_address","db_instance_endpoint_port","db_instance_status"
  end
  
  # currently unused
  parameter "param1" do
    label "param1"
    type "string"
    description "param1"
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

  # Wait until it is available.
  sleep_until(equals?(@my_rds.db_instance_status,"available"))

end

define delete_db(@rds) do
  
  # Delete the credentials created for the RDS DB access
  call utilities.log("deleting rds: "+to_s(@my_rds), to_s(to_object(@my_rds)))

  @rds.destroy() # Calls .delete on the API resource
end

# A support function for creating RDS snapshots.
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

