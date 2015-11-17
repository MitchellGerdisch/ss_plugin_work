require 'logger'

module V1
  class LoadBalancer
    include Praxis::Controller

    implements V1::ApiResources::LoadBalancer

    def index(**params)
      elb = V1::Helpers::Aws.get_elb_client

      begin
        load_balancers = []
        list_lbs_response = elb.describe_load_balancers

        list_lbs_response.load_balancer_descriptions.each do |load_balancer|
          load_balancers << { 
            "load_balancer_name": load_balancer.load_balancer_name,
            "load_balancer_dns": load_balancer.dns_name
          }
        end

        response = Praxis::Responses::Ok.new()
        response.body = JSON.pretty_generate(load_balancers)
        response.headers['Content-Type'] = V1::MediaTypes::LoadBalancer.identifier+';type=collection'
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end
    
    def create(**params)
      app = Praxis::Application.instance
      
      elb = V1::Helpers::Aws.get_elb_client
      
      lb_params = {
        load_balancer_name: request.payload.name,
        listeners: [
          {
            protocol: request.payload.lb_listener.protocol,
            load_balancer_port: request.payload.lb_listener.port,
            instance_protocol: request.payload.instance_listener.protocol,
            instance_port: request.payload.instance_listener.port
          }
        ],
        availability_zones: request.payload.availability_zones   # hard-coding this for now. later need to choose between az and subnets
      }

      begin
        create_lb_response = elb.create_load_balancer(lb_params)
        app.logger.info("lb create response: "+create_lb_response.dns_name)
       
        resp["lb_dns_name"] = create_lb_response.dns_name
        resp["href"] = "/elb/load_balancers/"+lb_params.load_balancer_name

        response = Praxis::Responses::Ok.new()
        response.headers['Content-Type'] = 'application/json'
        response.body = resp
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end
    
    def delete(id:, **params)
      app = Praxis::Application.instance
      
      elb = V1::Helpers::Aws.get_elb_client
      
      lb_params = {
        load_balancer_name: id,
      }

      begin
        elb_response = elb.delete_load_balancer(lb_params)        
        response = Praxis::Responses::Ok.new()
        response.headers['Content-Type'] = V1::MediaTypes::LoadBalancer.identifier+';type=collection'
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end

  end # class
end # module
