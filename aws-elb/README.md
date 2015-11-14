# Elastic Load Balancer Praxis App
A simple Praxis App to perform ELB CRUD requests from Self Service

## Limitations
It's single tenant, with the AWS credentials provided as environment variables (see [Credentials][])
It's hard-coded (helpers/aws.rb) to create ELB in us-east-1.

## Credentials
Requires a single set of AWS credentials provided as environment variables.

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

It also requires an API shared secret. This shared secret should be known only to your instance of this app, and the RightScale SelfService namespace you use to connect to it. It will be used to establish trust between these parties.

You provide the API shared secret as an environment variable

`API_SHARED_SECRET`

## TODO
* I'm sure there are all sorts of things I should be doing that I'm not.
