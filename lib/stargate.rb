##
# Version container for Stargate
##

module Stargate
  VERSION = "0.1.0".freeze

  def self.get_app( cfg )
    if cfg['target'] == 'app'
      return Stargate::Application.new( cfg )

    elsif cfg['target'] == 'inf'
      return Stargate::Infrastructure.new( cfg )

    else
      raise Exception.new(format('Unknown target: %s', cfg['target']))

    end
  end
end

module ToBoolean
  def to_bool
    return true if self == true || self.to_s.strip =~ /^(true|yes|y|1)$/i
    return false
  end
end

class NilClass; include ToBoolean; end
class TrueClass; include ToBoolean; end
class FalseClass; include ToBoolean; end
class Numeric; include ToBoolean; end
class String; include ToBoolean; end
