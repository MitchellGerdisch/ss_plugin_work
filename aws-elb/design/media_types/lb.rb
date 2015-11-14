module V1
  module MediaTypes
    class LoadBalancer < Praxis::MediaType

      identifier 'application/vnd.rightscale.load_balancer+json'
      @@kind = 'elb#load_balancer'

      attributes do
        attribute :kind, String
        attribute :id, String
        attribute :href, String
        attribute :name, String
        attribute :caller_reference, String
#        attribute :config do
#          attribute :comment, String
#          attribute :private_zone, String
#        end
#        attribute :resource_record_set_count, Integer
        attribute :links, Attributor::Collection.of(Hash)
      end

      view :default do
        attribute :kind
        attribute :id
        attribute :href
        attribute :name
        attribute :caller_reference
        attribute :config
        attribute :resource_record_set_count
        attribute :links
      end

      view :link do
        attribute :href
      end
    end
  end
end
