require 'securerandom'

module V1
  class LoadBalancer
    include Praxis::Controller

    implements V1::ApiResources::LoadBalancer

#    def do_delete(id, return_change=false)
#      elb = V1::Helpers::Aws.get_elb_client
#
#      begin
#        delete_response = elb.delete_hosted_zone(id: id)
#        if return_change
#          response = Praxis::Responses::Ok.new()
#          response.body = JSON.pretty_generate(V1::MediaTypes::Change.render(delete_response.change_info))
#          response.headers['Content-Type'] = V1::MediaTypes::Change.identifier
#        else
#          response = Praxis::Responses::NoContent.new()
#        end
#      rescue Aws::ElasticLoadBalancing::Errors::NoSuchHostedZone => e
#        response = Praxis::Responses::NotFound.new()
#        response.body = { error: e.inspect }
#      rescue  Aws::ElasticLoadBalancing::Errors::InvalidInput,
#              Aws::ElasticLoadBalancing::Errors::PriorRequestNotComplete,
#              Aws::ElasticLoadBalancing::Errors::HostedZoneNotEmpty => e
#        response = Praxis::Responses::BadRequest.new()
#        response.body = { error: e.inspect }
#      end
#      response
#    end

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
        ]
      }

      begin
        load_balancers = []
        create_lb_response = elb.create_load_balancer(lb_params)
        response.body = JSON.pretty_generate(create_lb_response)
        response.headers['Content-Type'] = V1::MediaTypes::LoadBalancer.identifier+';type=collection'
      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
        response = Praxis::Responses::BadRequest.new()
        response.body = { error: e.inspect }
      end

      response
    end

#    def show(id:, **other_params)
#      route53 = V1::Helpers::Aws.get_elb_client
#
#      # https://github.com/aws/aws-sdk-ruby/blob/9255277a1da95a6217f603e683bd49cc677a4b5a/aws-sdk-core/apis/route53/2013-04-01/api-2.json#L514-L525
#      begin
#        zone = elb.get_hosted_zone(id: id)
#        response = Praxis::Responses::Ok.new()
#        zone_hash = V1::Models::LoadBalancer.new(zone.hosted_zone)
#        response.body = JSON.pretty_generate(V1::MediaTypes::LoadBalancer.render(zone_hash))
#        response.headers['Content-Type'] = V1::MediaTypes::LoadBalancer.identifier
#      rescue Aws::ElasticLoadBalancing::Errors::NoSuchHostedZone => e
#        response = Praxis::Responses::NotFound.new()
#        response.body = { error: e.inspect }
#      rescue Aws::ElasticLoadBalancing::Errors::InvalidInput => e
#        response = Praxis::Responses::BadRequest.new()
#        response.body = { error: e.inspect }
#      end
#      response
#    end

#    def create(**other_params)
#      elb = V1::Helpers::Aws.get_elb_client
#
#      lb_params = {
#        name: request.payload.name,
##        caller_reference: SecureRandom.uuid,
#NEED TO WORK ON THIS TO REPRESENT WHAT I NEED - THIS IS COPIED FROM API DOC
#        listeners: [ # required
#            {
#              protocol: "Protocol", # required
#              load_balancer_port: 1, # required
#              instance_protocol: "Protocol",
#              instance_port: 1, # required
#              ssl_certificate_id: "SSLCertificateId",
#            },
#          ],
#          availability_zones: ["AvailabilityZone"],
#          subnets: ["SubnetId"],
#          security_groups: ["SecurityGroupId"],
#          scheme: "LoadBalancerScheme",
#          tags: [
#            {
#              key: "TagKey", # required
#              value: "TagValue",
#            },
#          ],
#        })
#
#      begin
#        aws_response = elb.create_load_balancer(lb_params)
#
#        response = Praxis::Responses::Created.new()
#        zone_model = V1::Models::LoadBalancer.new(aws_response.hosted_zone, aws_response.change_info)
#        # zone_shaped_hash = Hash[aws_response.hosted_zone]
#        # zone_shaped_hash[:change] = aws_response.change_info
#        # zone = V1::MediaTypes::PublicZone.render(zone_shaped_hash)
#        zone = V1::MediaTypes::LoadBalancer.render(zone_model)
#        response.body = JSON.pretty_generate(zone)
#        response.headers['Content-Type'] = V1::MediaTypes::LoadBalancer.identifier
#        response.headers['Location'] = zone[:href]
#      rescue  Aws::ElasticLoadBalancing::Errors::ConflictingDomainExists,
#              Aws::ElasticLoadBalancing::Errors::InvalidInput,
#              Aws::ElasticLoadBalancing::Errors::TooManyHostedZones,
#              Aws::ElasticLoadBalancing::Errors::InvalidDomainName => e
#        response = Praxis::Responses::BadRequest.new()
#        response.body = { error: e.inspect }
#      rescue Aws::ElasticLoadBalancing::Errors::HostedZoneAlreadyExists => e
#        resopnse = Praxis::Responses::Conflict.new()
#        resonse.body = { error: e.inspect }
#      end
#
#      response
#    end
#
#    def delete(id:, **other_params)
#      do_delete(id)
#    end
#
#    def release(id:, **other_params)
#      do_delete(id, true)
#    end

  end # class
end # module
