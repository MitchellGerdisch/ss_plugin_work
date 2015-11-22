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
    
########
# CREATE
########
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
            
      # Build params for the create      
      api_lb_params = {
        load_balancer_name: lb_name,
        subnets: request.payload.subnets,
        security_groups: request.payload.secgroups,
        availability_zones: request.payload.availability_zones,
        listeners: api_lb_listeners,
        scheme: request.payload.scheme,
      }
#      app.logger.info("api_lb_params: "+api_lb_params.to_s)
      
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
      
      # configure health check settings if those params were set
      if request.payload.key?(:healthcheck)  # Did the user specify healthcheck stuff? 
        
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
          # add healthcheck properties to the ELB
          healthcheck_response = elb.configure_health_check(api_healthcheck_params)
        rescue Aws::ElasticLoadBalancing::Errors::ValidationError,
               Aws::ElasticLoadBalancing::Errors::InvalidInput => e
          self.response = Praxis::Responses::BadRequest.new()
          response.body = { error: e.inspect }
        end
        
      end
      
      # build params for the other settings
      api_modify_lb_attributes_params = {
        load_balancer_name: lb_name,
        load_balancer_attributes: {
          cross_zone_load_balancing: {
            enabled: request.payload.cross_zone
          },
          connection_draining: {
            enabled: request.payload.key?(:connection_draining_timeout) ? true : false,
            timeout: request.payload.connection_draining_timeout
          },
          connection_settings: {
            idle_timeout: request.payload.connection_idle_timeout
          }
        }
      }
      
      begin
        # add other ELB attributes if provided
        attributes_response = elb.modify_load_balancer_attributes(api_modify_lb_attributes_params)
      rescue Aws::ElasticLoadBalancing::Errors::ValidationError,
               Aws::ElasticLoadBalancing::Errors::InvalidInput => e
          self.response = Praxis::Responses::BadRequest.new()
          response.body = { error: e.inspect }
      end
      
      # build params for the tags
      if request.payload.key?(:tags)  # Did the user specify tags stuff?
        api_tags = []
        tags_array = request.payload.tags
        tags_array.each do |tag|
          split_tag = tag.split(":")
          keyname = split_tag[0]
          val = split_tag.drop(1).join(":")  # need to account for the possibility that the tag value has colons. This drops the first value which should be the key and then puts things back if they were split above
          api_tag = {
            key: keyname,
            value: val
          }
          api_tags << api_tag
        end
        api_add_tags_params = {
          load_balancer_names: [lb_name],
          tags: api_tags
        }
      
        begin
          # add tags
          tagging_response = elb.add_tags(api_add_tags_params)
        rescue Aws::ElasticLoadBalancing::Errors::ValidationError,
                 Aws::ElasticLoadBalancing::Errors::InvalidInput => e
            self.response = Praxis::Responses::BadRequest.new()
            response.body = { error: e.inspect }
        end
      end
      
      # TO-DO: remove (backout) the ELB if there was a problem with a subsequent call (e.g. the health check config fails)
       
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
