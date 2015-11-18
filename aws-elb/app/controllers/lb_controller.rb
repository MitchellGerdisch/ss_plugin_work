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
        app.logger.info("success during show - response body: "+response.body.to_s)
      rescue  Aws::ElasticLoadBalancing::Errors::AccessPointNotFoundException,
              Aws::ElasticLoadBalancing::Errors::InvalidEndPointException => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
        app.logger.info("error during show - response body:: "+response.body.to_s)
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
      app.logger.info("lb_params: "+lb_params.to_s)


      begin
        create_lb_response = elb.create_load_balancer(lb_params)
        app.logger.info("lb create response: "+create_lb_response["dns_name"].to_s)
       
        resp_body = {}
        resp_body["lb_dns_name"] = create_lb_response["dns_name"]
        resp_body["load_balancer_name"] = request.payload.name
        resp_body["href"] = "/elb/load_balancers/" + request.payload.name
          
        app.logger.info("resp_body: "+resp_body.to_s)

        response = Praxis::Responses::Created.new()
        response.headers['Location'] = resp_body["href"]
        response.headers['Content-Type'] = 'application/json'
        response.body = resp_body
#        app.logger.info("success case - response header: "+response.headers.to_s)
#        app.logger.info("success case - response body: "+response.body.to_s)

      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        self.response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
        app.logger.info("error response body:"+response.body.to_s)
      end
      
        
      app.logger.info("departing response header: "+response.headers.to_s)
      app.logger.info("departing response body: "+response.body.to_s)

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
