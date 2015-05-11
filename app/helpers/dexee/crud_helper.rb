module Dexee
	module CrudHelper
		include ActionView::Helpers::NumberHelper

		# keep_dates = retain dates as date objects?
		def display_attr(resource, attr, link_if_model = false, additional_values = nil, value_type = nil, keep_dates = false, precision = nil)
			return nil if resource.nil?

			# nested attributes
			attr_parts = attr.to_s.split('.', 2)
			return display_attr(resource.send(attr_parts[0]), attr_parts[1], link_if_model, additional_values, value_type, keep_dates, precision) if attr_parts.length > 1

			return display_value(additional_values[attr], link_if_model, value_type, keep_dates, precision) if !additional_values.nil? and additional_values.include?(attr)
			model = get_model_from_attr(resource, attr)
			return display_value(model, link_if_model, value_type, keep_dates, precision) if !model.nil?
			return display_value(get_attr_on_resource(resource, attr), link_if_model, value_type, keep_dates, precision)
		end

		# Handles things like invoice.customer.phone
		def nested_lookup(resource, attr)
			return nil if resource.nil?
			attr_parts = attr.to_s.split('.', 2)
			return nil if !resource.respond_to?(attr_parts[0])
			v = resource.send(attr_parts[0])
			return v if attr_parts.length == 1
			return nested_lookup(v, attr_parts[1])
		end

		def display_value(value, link_if_model = false, value_type = nil, keep_dates = false, precision = nil, model_attribute = nil)
			return link_to(model_attribute.nil? ? value.display_text : value.send(model_attribute), value) if link_if_model && value.is_a?(ActiveRecord::Base) && dexee_user.can_access_model(value)
			return value.display_text if value.is_a?(ActiveRecord::Base)
			if value.is_a?(Date)
				return value if keep_dates
				return value.strftime('%b %e, %Y')
			end
			if value.is_a?(Time)
				return value.strftime('%b %e, %Y') if value_type == :date
				return value.strftime('%F %l:%M%p')
			end
			if value.is_a?(BigDecimal) or value.is_a?(Float)
				return "#{format_minimum_decimals(value, precision || 2, true)}" if value_type == :currency
				# show number with as many decimals needed?
				if value_type == :numeric_max_decimals
					value = value.to_i if value == value.to_i
					return value
				end
				return number_with_precision(value, :precision => precision || 3)
			end
			return number_to_phone(value, :area_code => true) if value_type == :tel
			return value
		end

		# Returns the model associated with the passed attribute, or nil if it's not a model
		def get_model_from_attr(resource, attr)
			return nil if resource.nil?
			model_attr = resource.class.to_model_attr(attr)
			return nil if model_attr.nil?
			return get_attr_on_resource(resource, model_attr)
		end

		def get_attr_on_resource(resource, attr)
			# it is quicker to ask for forgiveness...
			begin
				return resource.send(attr)
			rescue NoMethodError => ex
				return nil
			end
		end

	end
end
