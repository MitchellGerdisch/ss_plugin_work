require 'logger'

module V1
  class LoadBalancer
    include Praxis::Controller

    implements V1::ApiResources::LoadBalancer
    
    app = Praxis::Application.instance

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
        response.headers['Content-Type'] = 'application/json'
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end
    
    def show(id:, **params)
      app = Praxis::Application.instance
      
      elb = V1::Helpers::Aws.get_elb_client
      
      lb_params = {
        load_balancer_names: [id],
      }

      begin
        elb_response = elb.describe_load_balancers(lb_params)  
        lb_desc = elb_response.load_balancer_descriptions[0]
        
        resp_body = {}
        resp_body["load_balancer_name"] = lb_desc["load_balancer_name"]
        resp_body["lb_dns_name"] = lb_desc["dns_name"] 
        resp_body["href"] = "/elb/load_balancers/" + id

        response = Praxis::Responses::Ok.new()
        response.headers['Content-Type'] = 'application/json'
        response.body = resp_body
#        app.logger.info("success during show - response body: "+response.body.to_s)
      rescue  Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound => e
        response = Praxis::Responses::NotFound.new()
#        app.logger.info("elb not found during show: "+e.inspect.to_s)
      rescue  Aws::ElasticLoadBalancing::Errors::AccessPointNotFoundException,
              Aws::ElasticLoadBalancing::Errors::InvalidEndPointException => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
#        app.logger.info("error during show - response body: "+response.body.to_s)
      end

      response
    end
    
    def create(**params)
      app = Praxis::Application.instance
      
      elb = V1::Helpers::Aws.get_elb_client
      
      lb_name = request.payload.name
      
      # transfer the listener specs from the received API to the required format for the AWS ELB call
      api_lb_listeners = []
      listeners_hash_array = request.payload.listeners
      listeners_hash_array.each do |listener|
        api_lb_listener = {
        	protocol: listener["lb_protocol"],
        	load_balancer_port: listener["lb_port"],
        	instance_protocol: listener["instance_protocol"],
        	instance_port: listener["instance_port"]
	}
        api_lb_listeners << api_lb_listener
      end
                  
      api_lb_params = {
        load_balancer_name: lb_name,
        subnets: request.payload.subnets,
        security_groups: request.payload.secgroups,
        listeners: api_lb_listeners,
        scheme: request.payload.scheme,
      }
#      app.logger.info("api_lb_params: "+api_lb_params.to_s)
      
      api_healthcheck_params = {
        load_balancer_name: lb_name,
        health_check: {
          target: request.payload.healthcheck.target,
          interval: request.payload.healthcheck.interval,
          timeout: request.payload.healthcheck.timeout,
          unhealthy_threshold: request.payload.healthcheck.unhealthy_threshold,
          healthy_threshold: request.payload.healthcheck.healthy_threshold
        }
      }


      begin
        # create the ELB
        create_lb_response = elb.create_load_balancer(api_lb_params)
  
#        app.logger.info("lb create response: "+create_lb_response["dns_name"].to_s)
       
        # Build the response returned from the plugin service.
        # If there was a problem with calling AWS, it will be replaced by the error response.
        resp_body = {}
        resp_body["lb_dns_name"] = create_lb_response["dns_name"]
        resp_body["load_balancer_name"] = request.payload.name
        resp_body["href"] = "/elb/load_balancers/" + request.payload.name
          
#        app.logger.info("resp_body: "+resp_body.to_s)

        response = Praxis::Responses::Created.new()
        response.headers['Location'] = resp_body["href"]
        response.headers['Content-Type'] = 'application/json'
        response.body = resp_body
#        app.logger.info("success case - response header: "+response.headers.to_s)
#        app.logger.info("success case - response body: "+response.body.to_s)

      rescue Aws::ElasticLoadBalancing::Errors::ValidationError,
             Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        self.response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
#        app.logger.info("error response body:"+response.body.to_s)
      end
      
      begin
        # add healthcheck properties to the ELB
        healthcheck_response = elb.configure_health_check(api_healthcheck_params)
      rescue Aws::ElasticLoadBalancing::Errors::ValidationError,
             Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        self.response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end
       
#      app.logger.info("departing response header: "+response.headers.to_s)
#      app.logger.info("departing response body: "+response.body.to_s)

      response
    end
    
    def delete(id:, **params)
      app = Praxis::Application.instance
      
      elb = V1::Helpers::Aws.get_elb_client
      
      lb_params = {
        load_balancer_name: id,
      }

      response = Praxis::Responses::NoContent.new()

      begin
        elb_response = elb.delete_load_balancer(lb_params)        
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end

  end # class
end # module
