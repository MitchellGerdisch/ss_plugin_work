module V1
  module MediaTypes
    class LoadBalancer < Praxis::MediaType

      identifier 'application/vnd.rightscale.load_balancer+json'
      @@kind = 'elb#load_balancer'

      attributes do
        attribute :id, String
        attribute :href, String
        attribute :name, String
        attribute :availability_zones, Attributor::Collection.of(String)
        attribute :vpc, String
        attribute :subnets, Attributor::Collection.of(String)
        attribute :secgroups, Attributor::Collection.of(String)
        attribute :lb_listener do
          attribute :lb_protocol, String
          attribute :lb_port, String
        end
        attribute :instance_listener do
          attribute :instance_protocol, String
          attribute :instance_port, String
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
        attribute :subnet
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
