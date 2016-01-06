#require 'logger'
#

module V1
  module Helpers
    module Aws
      app = Praxis::Application.instance
      app.logger.info("In aws helper")

      def self.get_rds_client()
        credentials = ::Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
        elb = ::Aws::RDS::Client.new(region: 'us-east-1', credentials: credentials)
      end

    end
  end
end
