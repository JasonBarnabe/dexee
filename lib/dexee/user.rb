module Dexee
	module User

		def dexee_email
			return email if respond_to?(:email)
			raise 'You must implement dexee_email'
		end

		def can_access_controller(o)
			return true
		end

		def can_access_model(m)
			return true
		end

		def can_update_model(m)
			return true
		end

		def before_new_resource(r)
		end

		def apply_filters(controller_name, resources)
			return resources
		end

	end
end
