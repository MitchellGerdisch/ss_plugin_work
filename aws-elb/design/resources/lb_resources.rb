module V1
  module ApiResources
    class LoadBalancer
      include Praxis::ResourceDefinition

      media_type V1::MediaTypes::LoadBalancer
      version '1.0'
      prefix '/elb/load_balancers'
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
          attribute :name, required: true
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
          attribute :name, required: true
          attribute :lb_listener, required: true
          attribute :instance_listener, required: true
          attribute :stickiness
          attribute :availability_zones
          attribute :vpc
          attribute :subnets
          attribute :secgroups
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
