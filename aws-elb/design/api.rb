# Use this file to define your response templates and traits.
#
# For example, to define a response template:
#   response_template :custom do |media_type:|
#     status 200
#     media_type media_type
#   end
Praxis::ApiDefinition.define do
  # Trait that when included will require a Bearer authorization header to be passed in.
  trait :authorized do
    headers do
      key "X_Api_Shared_Secret", String, required: true
#      key "Aws_Access_Key_Id", String, required: true
#      key "Aws_Secret_Access_Key", String, required: true
    end
  end
end
