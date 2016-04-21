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
          get '/:instance_id'
        end
        params do
          attribute :instance_id, required: true
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
          attribute :master_username, required: true
          attribute :master_user_password, required: true
          attribute :db_security_groups
          attribute :vpc_security_group_ids
          attribute :tags
          attribute :aws_creds
        end
        response :created
        response :bad_request
      end

      action :delete do
        routing do
          delete '/:instance_id'
        end
        params do
          attribute :instance_id, String, required: true
        end
        response :no_content
        response :bad_request
        response :not_found
      end

    end
  end
end
