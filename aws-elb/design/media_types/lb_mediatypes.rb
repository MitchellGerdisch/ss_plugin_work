module V1
  module MediaTypes
    class LoadBalancer < Praxis::MediaType

      identifier 'application/json'
      
      resource "elb", type: "elb.load_balancer" do
        name  join([$elb_appname,"-",$param_elb_envtype,"-web-elb"])
        subnets  map($map_config, "Subnets", $param_elb_envtype)
        security_groups map($map_config, "SecurityGroups", $param_elb_envtype)
        healthcheck_target  "TCP:8080/index.html"
        healthcheck_interval "30"
        healthcheck_timeout "5"
        healthcheck_unhealthy_threshold "5"
        healthcheck_healthy_threshold "3"
        connection_draining_timeout "120" # if null then connection_draining_policy is disabled
        connection_idle_timeout "90"
        cross_zone  "true"
        scheme  "internal"
        listeners do [
          {
            "listener_name" => "elb_listener_http8080_http8080",
            "lb_protocol" => "HTTP",
            "lb__port" => "8080",
            "instance_protocol" => "HTTP",
            "instance_port" => "8080"
          },
          {
            "listener_name" => "elb_listener_http80_http80",
            "lb_protocol" => "HTTP",
            "lb__port" => "80",
            "instance_protocol" => "HTTP",
            "instance_port" => "80"
          }
        ] end
      # TODO add tagging stuff
      #  tags  $tags  
      end

      attributes do
        attribute :id, Attributor::String
        attribute :href, Attributor::String
        attribute :name, Attributor::String
        attribute :availability_zones, Attributor::Collection.of(String) 
        attribute :subnets, Attributor::Collection.of(String)
        attribute :secgroups, Attributor::Collection.of(String)
        attribute :listeners, Attributor::Collection.of(Hash)
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
        attribute :stickiness do
          attribute :stickiness_type, Attributor::String, values: ['disabled','lb_cookie', 'app_cookie']
          attribute :lb_cookie_expiration, Attributor::String
          attribute :app_cookie_name, Attributor::String
        end

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
      end

      view :link do
        attribute :href
      end
    end
  end
end
