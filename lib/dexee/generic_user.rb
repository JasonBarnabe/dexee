module Dexee
	class GenericUser
		include User

		def dexee_email
			return 'dexee@example.invalid'
		end
	end
end
