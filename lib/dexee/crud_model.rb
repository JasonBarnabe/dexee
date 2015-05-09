require 'active_support/concern'
require 'acts_as_xlsx'
require 'public_activity'
require 'schema_validations'
require 'strip_attributes'
require 'will_paginate'

module Dexee
	module CrudModel
		extend ActiveSupport::Concern
		include PublicActivity::Model

		included do
			acts_as_xlsx
			strip_attributes
			tracked owner: Proc.new{ |controller, model|
				next nil if controller.nil?
				# Make sure it's something in the DB
				du = controller.dexee_user
				next nil if du.nil?
				next nil if !du.is_a?(ActiveRecord::Base)
				next du
			}, on: {destroy: -> model, controller { model.persisted? }}
			schema_validations
		end

		def display_text
			return name if defined?(name)
			return "ID: #{id}"
		end

		# What shows up in autocomplete and drop downs if this is an attribute on a form
		def form_display_text
			display_text
		end

		# Should this show up in a child listing?
		def show_in_child_list?
			true
		end

		# Shows up differently in autocomplete because it's important?
		def highlight_in_autocomplete
			true
		end

		def child_list_filter_cutoff
			@child_lister_filter_cutoff ||= Rails.configuration.child_list_filter_years_ago.years.ago
		end

		def forgiving_equals?(o)
			return o == self if o.is_a?(ActiveRecord::Base)
			return o == id if o.is_a?(Integer)
			return o == name if o.is_a?(String)
			return false
		end

		def allow_delete?
			return false
		end

		module ClassMethods

			def use_combobox(search_fields = [:name])
				@_search_fields = search_fields
			end
			def search_fields
				@_search_fields
			end

			def load_model_attributes
				@_model_attributes = HashWithIndifferentAccess.new
				reflections.select {|k, v| v.is_a?(ActiveRecord::Reflection::AssociationReflection)}.each do |k, v|
					@_model_attributes[k] = k
					@_model_attributes[k.to_s + '_id'] = k
				end
			end
			def model_attributes
				load_model_attributes if @_model_attributes.nil?
				return @_model_attributes
			end
			# Returns the attribute name based on the passed name that contains a model, or nil.
			def to_model_attr(attr)
				return model_attributes[attr]
			end

			def get_model_class(attr)
				self.reflect_on_all_associations.each{|a|
						if a.name == attr.to_sym
							return a.options[:class_name].constantize if !a.options[:class_name].nil?
							return attr.to_s.singularize.camelize.constantize
						end
					}
				return nil
			end

			# What words to ignore when searching by autocomplete - should match any words added by display_text not in the DB fields
			def non_autocomplete_fields
				["ID"]
			end

		end

	end
end
