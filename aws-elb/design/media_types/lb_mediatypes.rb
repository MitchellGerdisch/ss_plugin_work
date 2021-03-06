module V1
  module MediaTypes
    class LoadBalancer < Praxis::MediaType

      identifier 'application/json'

      attributes do
        attribute :id, Attributor::String
        attribute :href, Attributor::String
        attribute :name, Attributor::String
        attribute :availability_zones, Attributor::Collection.of(String) 
        attribute :subnets, Attributor::Collection.of(String)
        attribute :secgroups, Attributor::Collection.of(String)
        attribute :listeners, Attributor::Collection.of(Hash)
          # Listener Hash Structure:
          #    "listener_name" => string,
          #     "lb_protocol" => protocol type (e.g. TCP, HTTP, HTTPS) ELB listens for
          #     "lb_port" => port ELB listens on
          #     "instance_protocol" => protocol type the back end instances are listening on and ELB forwards to
          #     "instance_port" => port back end instances are listening on and ELB forwards to
          #     "sticky" => true or false indicates whether or not to attach the stickiness policy defined below
        attribute :healthcheck do
          attribute :target, Attributor::String
          attribute :interval, Attributor::Integer
          attribute :timeout, Attributor::Integer
          attribute :unhealthy_threshold, Attributor::Integer
          attribute :healthy_threshold, Attributor::Integer
        end
        attribute :connection_draining_timeout, Attributor::Integer
        attribute :connection_idle_timeout, Attributor::Integer
        attribute :cross_zone, Attributor::String
        attribute :scheme, Attributor::String
        attribute :stickiness do # TO-DO support multiple stickiness policies
          attribute :stickiness_type, Attributor::String, values: ['lb_cookie', 'app_cookie']
          attribute :lb_cookie_expiration, Attributor::String
          attribute :app_cookie_name, Attributor::String
        end
        attribute :tags, Attributor::Collection.of(String)
        attribute :aws_creds, Attributor::Collection.of(String)

      end

      view :default do
        attribute :id
        attribute :href
        attribute :name
        attribute :subnets
        attribute :secgroups
        attribute :listeners
        attribute :healthcheck
        attribute :connection_draining_timeout 
        attribute :connection_idle_timeout 
        attribute :cross_zone
        attribute :scheme
        attribute :stickiness
        attribute :tags
      end

      view :link do
        attribute :href
      end
    end
  end
end
