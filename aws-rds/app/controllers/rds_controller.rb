require 'logger'

module V1
  class RDS
    include Praxis::Controller

    implements V1::ApiResources::RDS
    
    app = Praxis::Application.instance

    def index(**params)
      rds = V1::Helpers::Aws.get_rds_client

      begin
        my_db_instances = []
        list_rds_response = rds.describe_db_instances

        list_rds_response.db_instances.each do |db_instance|
          my_db_instances << { 
            "db_instance_id": db_instance.db_instance_identifier,
            "db_name": db_instance["db_name"],
            "db_fqdn": db_instance.endpoint["address"],
            "db_port": db_instance.endpoint["port"]
          }
        end

        response = Praxis::Responses::Ok.new()
        response.body = JSON.pretty_generate(my_db_instances)
        response.headers['Content-Type'] = 'application/json'
      rescue Aws::RDS::Errors::ResourceNotFoundFault => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end
    
    def show(id:, **params)
      app = Praxis::Application.instance
      
      rds = V1::Helpers::Aws.get_rds_client
      
      rds_params = {
        db_instance_identifier: id,
      }

      begin
        rds_response = rds.describe_db_instances(rds_params)  
        rds_desc = rds_response.db_instances[0]
        
        resp_body = {}
        resp_body["instance_name"] = rds_desc["db_instance_identifier"]
        resp_body["instance_endpoint_address"] = rds_desc["endpoint"]["address"] 
        resp_body["instance_endpoint_port"] = rds_desc["endpoint"]["port"]
        resp_body["href"] = "/rds/instances/" + id

        response = Praxis::Responses::Ok.new()
        response.headers['Content-Type'] = 'application/json'
        response.body = resp_body
#        app.logger.info("success during show - response body: "+response.body.to_s)
      rescue  Aws::RDS::Errors::DBInstanceNotFoundFault => e
        response = Praxis::Responses::NotFound.new()
#        app.logger.info("rds not found during show: "+e.inspect.to_s)
      rescue  Aws::RDS::Errors::InvalidDBInstanceStateFault,
              Aws::RDS::Errors::DBInstanceAlreadyExistsFault => e
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
      
      # NOTE THE ASSUMPTION IS THAT HTTPS IS BEING USED SO KEYS ARE NOT SNIFFABLE
      if request.payload.aws_creds
        aws_access_key_id = request.payload.aws_creds[0]
        aws_secret_access_key = request.payload.aws_creds[1]
        # Place them in the environment so they can be used for the AWS calls
        ENV['AWS_ACCESS_KEY_ID'] = aws_access_key_id
        ENV['AWS_SECRET_ACCESS_KEY'] = aws_secret_access_key
      end
      
      rds = V1::Helpers::Aws.get_rds_client
            
      # Build params for the create      
      api_params = {
        db_name: request.payload.db_name.to_s,
        db_instance_identifier: request.payload.instance_id,
        allocated_storage: request.payload.allocated_storage,
        db_instance_class: request.payload.instance_class,
        engine: request.payload.engine, # MySQL
        master_username: request.payload.master_username,
        master_user_password: request.payload.master_password,
        multi_az: false
      }
      app.logger.info("api__params: "+api_params.to_s)
      
      begin
        # create the RDS
        create_rds_response = rds.create_db_instance(api_lb_params)
  
#        app.logger.info("lb create response: "+create_lb_response["dns_name"].to_s)
       
        # Build the response returned from the plugin service.
        # If there was a problem with calling AWS, it will be replaced by the error response.
        resp_body = {}
          
        resp_body["rds_instance_name"] = request.payload.name
        resp_body["rds_endpoint_address"] = create_rds_response["endpoint"]["address"]
        resp_body["rds_endpoint_port"] = create_rds_response["endpoint"]["port"]
        resp_body["href"] = "/rds/instances/" + request.payload.name
          
#        app.logger.info("resp_body: "+resp_body.to_s)

        response = Praxis::Responses::Created.new()
        response.headers['Location'] = resp_body["href"]
        response.headers['Content-Type'] = 'application/json'
        response.body = resp_body
#        app.logger.info("success case - response header: "+response.headers.to_s)
#        app.logger.info("success case - response body: "+response.body.to_s)

      rescue Aws::RDS::Errors::ValidationError,
             Aws::RDS::Errors::InvalidInput => e
        self.response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
#        app.logger.info("error response body:"+response.body.to_s)
      end
      
      # configure health check settings if those params were set
      if request.payload.key?(:healthcheck)  # Did the user specify healthcheck stuff? 
        
        api_healthcheck_params = {
          instance_name: lb_name,
          health_check: {
            target: request.payload.healthcheck.target,
            interval: request.payload.healthcheck.interval,
            timeout: request.payload.healthcheck.timeout,
            unhealthy_threshold: request.payload.healthcheck.unhealthy_threshold,
            healthy_threshold: request.payload.healthcheck.healthy_threshold
          }
        }
        
        begin
          # add healthcheck properties to the RDS
          healthcheck_response = rds.configure_health_check(api_healthcheck_params)
        rescue Aws::RDS::Errors::ValidationError,
               Aws::RDS::Errors::InvalidInput => e
          self.response = Praxis::Responses::BadRequest.new()
          response.body = { error: e.inspect }
        end
        
      end
      
      if request.payload.key?(:cross_zone) || request.payload.key?(:connection_draining_timeout) # Did the user specify healthcheck stuff? 
        # build params for the other settings
        api_modify_lb_attributes_params = {
          instance_name: lb_name,
          instance_attributes: {
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
          # add other RDS attributes if provided
          attributes_response = rds.modify_instance_attributes(api_modify_lb_attributes_params)
        rescue Aws::RDS::Errors::ValidationError,
                 Aws::RDS::Errors::InvalidInput => e
            self.response = Praxis::Responses::BadRequest.new()
            response.body = { error: e.inspect }
        end
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
          instance_names: [lb_name],
          tags: api_tags
        }
      
        begin
          # add tags
          tagging_response = rds.add_tags(api_add_tags_params)
        rescue Aws::RDS::Errors::ValidationError,
                 Aws::RDS::Errors::InvalidInput => e
            self.response = Praxis::Responses::BadRequest.new()
            response.body = { error: e.inspect }
        end
      end
      
      # TO-DO: remove (backout) the RDS if there was a problem with a subsequent call (e.g. the health check config fails)
       
#      app.logger.info("departing response header: "+response.headers.to_s)
#      app.logger.info("departing response body: "+response.body.to_s)

      response
    end
    
    def delete(id:, **params)
      app = Praxis::Application.instance
      
      rds = V1::Helpers::Aws.get_rds_client
      
      rds_params = {
        db_instance_identifier: id,
        skip_final_snapshot: true
      }

      response = Praxis::Responses::NoContent.new()

      begin
        rds_response = rds.delete_db_instance(rds_params)        
      rescue Aws::RDS::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end
      
      # TODO: Put in some looping to wait until fully deleted before returning since it can take a few minutes for the RDS
      # instance to be deleted. Currently the CAT will have to do this.

      response
    end

  end # class
end # module
