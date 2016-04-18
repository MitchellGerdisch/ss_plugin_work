require 'logger'

module V1
  class RDS
    include Praxis::Controller

    implements V1::ApiResources::RDS
    
    app = Praxis::Application.instance

    def index(**params)
      
      Praxis::Application.instance.logger.info "In index function"
      rds = V1::Helpers::Aws.get_rds_client
      Praxis::Application.instance.logger.info "After AWS API call"


      begin
        Praxis::Application.instance.logger.info "In AWS response processing section"
        my_db_instances = []
        list_rds_response = rds.describe_db_instances

        list_rds_response.db_instances.each do |db_instance|
          Praxis::Application.instance.logger.info "db_instance from AWS: "+db_instance.to_s
          
          # The endpoint may not be defined yet if the instance is still creating.
          db_endpoint = "not available yet"
          db_port = "not available yet"
          if db_instance.endpoint
            db_endpoint = db_instance.endpoint["address"]
            db_port = db_instance.endpoint["port"]
          end
          
          my_db_instances << { 
            "db_instance_id": db_instance.db_instance_identifier,
            "db_name": db_instance["db_name"],
            "db_fqdn": db_endpoint,
            "db_port": db_port,
            "db_instance_status": db_instance["db_instance_status"]
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
    
    def show(instance_id:, **params)
      app = Praxis::Application.instance
      
      rds = V1::Helpers::Aws.get_rds_client
      
      rds_params = {
        db_instance_identifier: instance_id,
      }

      begin
        rds_response = rds.describe_db_instances(rds_params)  
        rds_desc = rds_response.db_instances[0]
        
        resp_body = {}
        resp_body["db_instance_name"] = rds_desc["db_instance_identifier"]
        resp_body["db_name"] = rds_desc["db_name"]
        # The endpoint may not be defined yet if the instance is still creating.
        resp_body["db_instance_endpoint_address"] =  "not available yet"
        resp_body["db_instance_endpoint_port"] = "not available yet"
        if rds_desc.endpoint
          resp_body["db_instance_endpoint_address"] = rds_desc["endpoint"]["address"] 
          resp_body["db_instance_endpoint_port"] = rds_desc["endpoint"]["port"]
        end
        resp_body["db_instance_status"] = rds_desc["db_instance_status"]
        resp_body["href"] = "/rds/instances/" + instance_id

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
      
      Praxis::Application.instance.logger.info "In RDS create section"
      
      # NOTE THE ASSUMPTION IS THAT HTTPS IS BEING USED SO KEYS ARE NOT SNIFFABLE
      if request.payload.aws_creds
        Praxis::Application.instance.logger.info "Found AWS creds in request"
        aws_access_key_id = request.payload.aws_creds[0]
        aws_secret_access_key = request.payload.aws_creds[1]
        # Place them in the environment so they can be used for the AWS calls
        ENV['AWS_ACCESS_KEY_ID'] = aws_access_key_id
        ENV['AWS_SECRET_ACCESS_KEY'] = aws_secret_access_key
      end
      
      Praxis::Application.instance.logger.info "Before AWS RDS Create API call"
      rds = V1::Helpers::Aws.get_rds_client
      Praxis::Application.instance.logger.info "After AWS RDS Create API call"

            
      # Build params for the create      
      api_params = {
        db_name: request.payload.db_name,
        db_instance_identifier: request.payload.instance_id,
        allocated_storage: request.payload.allocated_storage,
        db_instance_class: request.payload.instance_class,
        engine: request.payload.engine, # MySQL
        master_username: request.payload.master_username,
        master_user_password: request.payload.master_user_password,
        multi_az: false
      }
#      app.logger.info("api_params: "+api_params.to_s)
      
      begin
        # create the RDS
        Praxis::Application.instance.logger.info "RDS api_params: "+api_params.to_s

        create_rds_response = rds.create_db_instance(api_params)
  
        Praxis::Application.instance.logger.info "RDS Create response"+create_rds_response.to_s
       
        # Build the response returned from the plugin service.
        # If there was a problem with calling AWS, it will be replaced by the error response.
        resp_body = {}
          
        resp_body["rds_instance_name"] = request.payload.instance_id
        resp_body["rds_db_name"] = request.payload.db_name
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
      # TO-DO: remove (backout) the RDS if there was a problem with a subsequent call (e.g. the health check config fails)
       
#      app.logger.info("departing response header: "+response.headers.to_s)
#      app.logger.info("departing response body: "+response.body.to_s)

      Praxis::Application.instance.logger.info "Before RDS Create response return"

      response

      Praxis::Application.instance.logger.info "After RDS Create response return"

    end
    
    def delete(instance_id:, **params)
      app = Praxis::Application.instance
      
      rds = V1::Helpers::Aws.get_rds_client
      
      rds_params = {
        db_instance_identifier: instance_id,
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
