module Dexee
  class Engine < ::Rails::Engine
    isolate_namespace Dexee
    
    # For asset inclusion
    require 'jquery-ui-rails'
  end
end
