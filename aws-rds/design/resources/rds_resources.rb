module V1
  module ApiResources
    class RDS
      include Praxis::ResourceDefinition

      media_type V1::MediaTypes::RDS
      version '1.0'
      prefix '/rds/instances'
      trait :authorized

      action :index do
        routing do
          get ''
        end
        response :ok
      end

      action :show do
        routing do
          get '/:id'
        end
        params do
          attribute :id, required: true
        end
        response :ok
        response :not_found
        response :bad_request
      end

      action :create do
        routing do
          post ''
        end
        payload do
          attribute :db_name, required: true
          attribute :instance_id, required: true
          attribute :instance_class, required: true
          attribute :engine, required: true
          attribute :allocated_storage, required: true
          attribute :major_version_upgrade
          attribute :minor_version_upgrade
          attribute :backup_retention_period
          attribute :engine_version
          attribute :license_model
          attribute :master_username, required: true
          attribute :master_user_password, required: true
          attribute :multi_az
          attribute :port
          attribute :preferred_backup_window
          attribute :preferred_maintenance_window
          attribute :deletion_policy
          attribute :publicly_accessible
          attribute :storage_encrypted
          attribute :storage_type
          attribute :vpc_secgroups
          attribute :subnet_group_name
          attribute :tags
          attribute :aws_creds
        end
        response :created
        response :bad_request
      end

      action :delete do
        routing do
          delete '/:id'
        end
        params do
          attribute :id, String, required: true
        end
        response :no_content
        response :bad_request
        response :not_found
      end

    end
  end
end
