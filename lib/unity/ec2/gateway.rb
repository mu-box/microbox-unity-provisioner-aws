class Unity::EC2::Gateway < Unity::EC2::Base

  def list
    list = []

    # filter the collection to just microbox instances
    filter = [{'Name'  => 'tag:Microbox', 'Value' => 'true'}]

    # query the api
    res = manager.DescribeInternetGateways('Filter' => filter)

    # extract the instance collection
    gateways = res["DescribeInternetGatewaysResponse"]["internetGatewaySet"]

    # short-circuit if the collection is empty
    return [] if gateways.nil?

    # gateways might not be a collection, but a single item
    collection = begin
      if gateways['item'].is_a? Array
        gateways['item']
      else
        [gateways['item']]
      end
    end

    # grab the gateways and process them
    collection.each do |gateway|
      list << process(gateway)
    end

    list
  end

  def show(name)
    list.each do |gateway|
      if gateway[:name] == name
        return gateway
      end
    end

    # return nil if we can't find it
    nil
  end

  def create(name)
    # short-circuit if this already exists
    existing = show(name)
    if existing
      logger.info "Internet Gateway '#{name}' already exists"
      return existing
    end

    # create the gateway
    logger.info("Creating Internet Gateway '#{name}'")
    gateway = create_gateway(name)

    # tag the gateway
    logger.info("Tagging Internet Gateway '#{name}'")
    tag_gateway(gateway['internetGatewayId'], name)

    # process the gateway
    process(gateway)
  end

  def attach(vpc, gateway)
    # short-circuit if this already exists
    if gateway[:attached_vpcs].include? vpc[:id]
      logger.info "Internet Gateway '#{gateway[:name]}' already attached to VPC '#{vpc[:name]}'"
      return true
    end


    # attach the gateway to the vpc
    logger.info "Attaching Internet Gateway '#{gateway[:name]}' to VPC '#{vpc[:name]}'"
    res = manager.AttachInternetGateway(
      'InternetGatewayId' => gateway[:id],
      'VpcId'             => vpc[:id]
    )

    # find out if it was attached
    res["AttachInternetGatewayResponse"]["return"]
  end

  protected

  def create_gateway(name)
    # create an internet gateway
    res = manager.CreateInternetGateway()

    # extract the response
    res["CreateInternetGatewayResponse"]["internetGateway"]
  end

  def tag_gateway(id, name)
    # tag the vpc
    res = manager.CreateTags(
      'ResourceId'  => id,
      'Tag' => [
        {
          'Key' => 'Microbox',
          'Value' => 'true'
        },
        {
          'Key' => 'Name',
          'Value' => "Microbox-Unity-#{name}"
        },
        {
          'Key' => 'EnvName',
          'Value' => name
        }
      ]
    )
  end

  def process(data)
    {
      id:             data["internetGatewayId"],
      name:           (process_tag(data['tagSet']['item'], 'EnvName') rescue 'unknown'),
      attached_vpcs:  extract_attached_vpc_ids(data['attachmentSet'])
    }
  end

  def process_tag(tags, key)
    tags.each do |tag|
      if tag['key'] == key
        return tag['value']
      end
    end
    ''
  end

  def extract_attached_vpc_ids(set)
    return [] if set.nil?

    collection = begin
      if set['item'].is_a? Array
        set['item']
      else
        [set['item']]
      end
    end

    collection.map do |attachment|
      attachment['vpcId']
    end
  end

end
