class Unity::EC2::Base
  
  attr_reader :manager
  attr_reader :logger
  
  def initialize(manager, logger, log_prefix='')
    @manager = manager
    @logger  = logger
  end
  
end
