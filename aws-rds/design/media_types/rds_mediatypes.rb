module V1
  module MediaTypes
    class RDS < Praxis::MediaType

      identifier 'application/json'

      attributes do
        attribute :id, Attributor::String
        attribute :href, Attributor::String
        attribute :name, Attributor::String
        attribute :allocated_storage, Attributor::Integer
        attribute :major_version_upgrade, Attributor::String
        attribute :minor_version_upgrade, Attributor::String
        attribute :backup_retention_period, Attributor::Integer
        attribute :instance_class, Attributor::String
        attribute :instance_id, Attributor::String
        attribute :engine, Attributor::String
        attribute :engine_version, Attributor::String
        attribute :license_model, Attributor::String
        attribute :master_username, Attributor::String
        attribute :master_user_password, Attributor::String
        attribute :multi_az, Attributor::String
        attribute :port, Attributor::Integer
        attribute :preferred_backup_window, Attributor::String
        attribute :preferred_maintenance_window, Attributor::String
        attribute :deletion_policy, Attributor::String
        attribute :publicly_accessible, Attributor::String
        attribute :storage_encrypted, Attributor::String
        attribute :storage_type, Attributor::String
        attribute :vpc_secgroups, Attributor::Collection.of(String)
        attribute :subnet_group_name, Attributor::String
        attribute :tags, Attributor::Collection.of(String)
        attribute :aws_creds, Attributor::Collection.of(String)

      end

      view :default do
        attribute :id, Attributor::String
        attribute :href, Attributor::String
        attribute :name, Attributor::String
        attribute :allocated_storage, Attributor::Integer
        attribute :instance_class, Attributor::String
        attribute :instance_id, Attributor::String
        attribute :engine, Attributor::String
        attribute :engine_version, Attributor::String
        attribute :multi_az, Attributor::String
        attribute :port, Attributor::Integer
        attribute :storage_type, Attributor::String
        attribute :vpc_secgroups, Attributor::Collection.of(String)
        attribute :subnet_group_name, Attributor::String
        attribute :tags, Attributor::Collection.of(String)
      end

      view :link do
        attribute :href
      end
    end
  end
end
