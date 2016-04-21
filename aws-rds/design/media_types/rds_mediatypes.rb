module V1
  module MediaTypes
    class RDS < Praxis::MediaType

      identifier 'application/json'

      attributes do
        attribute :db_name, Attributor::String
        attribute :instance_id, Attributor::String
        attribute :instance_class, Attributor::String
        attribute :engine, Attributor::String
        attribute :allocated_storage, Attributor::Integer
        attribute :master_username, Attributor::String
        attribute :master_user_password, Attributor::String
        attribute :db_security_groups, Attributor::Collection.of(String)
        attribute :vpc_security_group_ids, Attributor::Collection.of(String)
        attribute :tags, Attributor::Collection.of(String)
        attribute :aws_creds, Attributor::Collection.of(String)

      end

      view :default do
        attribute :href, Attributor::String
        attribute :db_name, Attributor::String
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
