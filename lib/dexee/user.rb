module Dexee
	module User

		def name
			return 'Dexee User'
		end

		def display_text
			return 'Dexee User'
		end

		def dexee_email
			return email if respond_to?(:email)
			return 'dexee@example.invalid'
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
