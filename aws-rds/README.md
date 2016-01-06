# Elastic Load Balancer Praxis App
A simple Praxis App to perform ELB CRUD requests from Self Service

## Limitations
It's single tenant, with the AWS credentials provided as environment variables (see [Credentials][])
It's hard-coded (helpers/aws.rb) to create ELB in us-east-1.

## Credentials
You provide the API shared secret as an environment variable

`API_SHARED_SECRET`

Assumes there is an nginx reverse proxy in front of it to provide HTTPS access and that the AWS keys are provided 
as part of the create operation

## TODO
* I'm sure there are all sorts of things I should be doing that I'm not.
