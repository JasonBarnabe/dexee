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
			return can_access_model(m)
		end

		def can_create_model(klass)
			return true
		end

		def can_delete_model(m)
			return can_update_model(m)
		end

		def before_new_resource(r)
		end

		def apply_filters(controller_name, resources)
			return resources
		end

	end
end
