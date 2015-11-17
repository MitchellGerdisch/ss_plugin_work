module V1
  module MediaTypes
    class LoadBalancer < Praxis::MediaType

      identifier 'application/json'

      attributes do
        attribute :id, String
        attribute :href, String
        attribute :name, String
        attribute :availability_zones, Attributor::Collection.of(String) 
        attribute :vpc, String
        attribute :subnets, Attributor::Collection.of(String)
        attribute :secgroups, Attributor::Collection.of(String)
        attribute :lb_listener do
          attribute :protocol, String
          attribute :port, String
        end
        attribute :instance_listener do
          attribute :protocol, String
          attribute :port, String
        end
        attribute :stickiness do
          attribute :stickiness_type, String, values: ['disabled','lb_cookie', 'app_cookie']
          attribute :lb_cookie_expiration, String
          attribute :app_cookie_name, String
        end

      end

      view :default do
        attribute :id
        attribute :href
        attribute :name
        attribute :vpc
        attribute :subnets
        attribute :secgroups
        attribute :lb_listener
        attribute :instance_listener
        attribute :stickiness
      end

      view :link do
        attribute :href
      end
    end
  end
end
