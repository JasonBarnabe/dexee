# This is included by schema_validations and turns itself on by default!
require 'schema_plus'

SchemaPlus.setup do |config|
	config.foreign_keys.auto_create = false
end
