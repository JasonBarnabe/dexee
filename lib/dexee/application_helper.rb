module Dexee
  module ApplicationHelper

		def title(page_title)
			content_for(:title) { page_title }
		end

		def format_minimum_decimals(number, decimals, currency = false)
			return number if number.nil? || number.is_a?(String)
			if number.to_f == (number*10**decimals).to_i / (10**decimals).to_f
				return (currency ? '$' : '') + ("%.0" + decimals.to_s + "f") % number
			end
			return (currency ? '$' : '') + number.to_s
		end

  end
end
