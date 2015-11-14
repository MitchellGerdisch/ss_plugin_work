NOT EVEN CLOSE TO READY - MOSTLY A COPY OF THE ROUTE53 EXAMPLE


name "Namespace and sanity test of ELB plugin"
rs_ca_ver 20131202
short_description "Namespace and sanity test of ELB plugin"

resource "my_elb", type: "elb.lb" do
  name "??????"
end



namespace "elb" do
  service do
    host "Change to your endpoint" # HTTP endpoint presenting an API defined by self-serviceto act on resources
    path "/elb"  # path prefix for all resources, RightScale account_id substituted in for multi-tenancy
    headers do {
      "user-agent" => "self_service" ,     # special headers as needed
      "X-Api-Version" => "1.0",
      "X-Api-Shared-Secret" => "Change to a shared secret value"
    } end
  end
  type "lb" do
    fields do
      field "name" do
        type "string"
        required true
      end
    end
  end

  type "record" do
    provision "provision_record"
    fields do
      field "zone" do
        type "resource"
      end
      field "name" do
        type "string"
        required true
      end
      field "type" do
        type "string"
        required true
      end
      field "ttl" do
        type "number"
        required true
      end
      field "values" do
        type "array"
        required true
      end
    end
  end
end

define provision_record(@raw_record) return @resource do
  $zone_href_parts = split(@raw_record.zone_href,'/')
  $zone_id = last($zone_href_parts)
  @resource = route53.record.create({
    public_zone_id: $zone_id,
    name: @raw_record.name,
    type: @raw_record.type,
    ttl: @raw_record.ttl,
    values: @raw_record.values
  })
end

operation "terminate" do
  definition "terminate"
  description "Kill the DNS record before the zone"
end

define terminate(@dns_zone, @dns_record) do
  delete(@dns_record)
  delete(@dns_zone)
end
