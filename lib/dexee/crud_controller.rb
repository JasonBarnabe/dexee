require 'active_support/concern'
require 'dexee/application_helper'
require 'dexee/crud_helper'
require 'dexee/generic_mailer'
require 'public_activity'

module Dexee
	module CrudController
		extend ActiveSupport::Concern
		include Dexee::ApplicationHelper
		include Dexee::CrudHelper
		include ::PublicActivity::StoreController

		included do
			respond_to :html, :json
			respond_to :xlsx, :only => :index

			helper WickedPdfHelper
			helper ApplicationHelper
			helper CrudHelper

			helper_method :attrs_for_index
			helper_method :attrs_for_form
			helper_method :attrs_for_show
			helper_method :attrs_for_associate
			helper_method :children_for_show
			helper_method :additional_show_actions
			helper_method :children_for_form
			helper_method :get_controller_for_attr
			helper_method :get_controller_for_model
			helper_method :inverse_attribute
			helper_method :model_class
			helper_method :model_name
			helper_method :show_new_child_link
			helper_method :show_delete_in_list?
			helper_method :generate_new_child_link
			helper_method :child_is_association
			helper_method :filters_active?
			helper_method :child_row_limit
			helper_method :child_row_limit_override
			helper_method :render_pdf_content
			helper_method :dexee_user

			before_filter :restrict_by_controller

			# Because we're a module and not a class, gotta set up all this junk
			before_filter do
				lookup_context.prefixes << 'dexee/crud' unless lookup_context.prefixes.include?('dexee/crud')
			end
			layout 'layouts/dexee/crud'
		end

		# Return an object representing the current logged in user, which includes Dexee::User
		def dexee_user
			return GenericUser.new
		end

		###
		# attrs_for_*: a hash of attribute name to option hash that will be displayed
		###

		def attrs_for_index
			return all_attrs_except(filter_attributes + only_on_show_attributes, true)
		end

		def attrs_for_export
			# all attributes shown on the index and show pages, then all attributes
			attrs = attrs_for_index
			attrs.merge!(attrs_for_show)
			model_class.attribute_names.each do |a|
				attrs[a.to_sym] = {} if a != 'id'
			end
			# take out cases where we have resource and resource_id
			attrs.delete_if {|a| a.to_s.ends_with?('_id') && attrs.include?(a.to_s.sub(/_id$/, '').to_sym)}
			new_attrs = {}
			attrs.each{|a, opts|
				if a.to_s.ends_with?('_id')
					without_id = a.to_s.sub(/_id$/, '').to_sym
					a = without_id if model_class.method_defined?(without_id)
				end
				new_attrs[a] = opts
			}
			return new_attrs
		end

		def attrs_for_show
			return all_attrs_except(filter_attributes, true)
		end

		def attrs_for_form
			return all_attrs_except(filter_attributes + only_on_show_attributes + [:id], true)
		end

		def attrs_for_associate(child_name)
			child_controller = get_controller_for_model(child_name)
			return child_controller.attrs_for_index.dup
		end

		###
		# includes_for_*: passed to finder.includes
		###

		def includes_for_show
			i = []
			attrs_for_show.each do |attr, opts|
				i << attr if !get_model_class(attr).nil?
			end
			children_for_show.each do |child, opts|
				model_class = get_model_class(child)
				if !model_class.nil?
					controller = get_controller_for_model(model_class)
					i << {child => controller.includes_for_index}
				end
			end
			return i
		end

		def includes_for_index
			i = []
			attrs_for_index.each do |attr, opts|
				i << attr if !get_model_class(attr).nil?
			end
			return i
		end

		def includes_for_export
			includes_for_index
		end

		###
		# *_lookup_chain: things to apply to the index finder (includes, sorts, etc.)
		###

		def index_lookup_chain(finder)
			finder
		end

		def show_lookup_chain(finder)
			finder
		end

		def export_lookup_chain(finder)
			index_lookup_chain(finder)
		end

		def autocomplete_lookup_chain(finder)
			finder
		end

		###
		# additional_*_values: hash of additional values to show that aren't part of the model, for example things that are easily calculated en masse but would be too slow to calculate for each model individually
		###

		def additional_index_values
			{}
		end

		def additional_show_values
			{}
		end

		# How many children of a type to show when the limit is enabled
		def child_row_limit
			25
		end

		def child_row_limit_override(attr)
			return params["filter_#{attr.to_s}"].nil? ? nil : params["filter_#{attr.to_s}"].to_i
		end

		# Number of entries per page to show on the index
		def index_per_page
			100
		end

		# Whether to limit the number of child rows on a show page - limited by count and show_in_child_list?
		def filter_children_on_show
			false
		end

		# Child records to show on the show screen. Relationship name to options hash. Options hash includes:
		# - attrs: override the default attributes of each child to show
		# - label: the heading to appear before each kind of children
		def children_for_show
			{}
		end

		# Override how the children will be looked up - can be useful there's a ton of data and you want to more
		# intelligently load it. Should be a child_name key (matching an entry in children_for_show) to a Proc which
		# accepts the parent object and returns a hash with :objects and :total_count
		def alternate_children_for_show_lookups
			{}
		end

		# Performs a child record lookup separately from the parent. Useful when a limit or filter is in play
		# and loading all the records, including other related records needed for display, is too heavy. This
		# will perform two queries - one minimal one to decide which to display, and then a full one to load
		# all necessary data for display.
		#
		# When child_row_limit_override is not provided, will grab child_row_limit records where show_in_child_list?
		# is true. When it is provided, will grab the number of records it specifies, not filtered.
		#
		# child_name - child name on the controller
		# filtering_finder - looks up enough of the record to decide whether that record will be displayed
		# complete_finder - looks up all records, with everything needed to display them. will be filtered by
		#                   ids found by filtering finder
		def child_separate_lookup(child_name, filtering_finder, complete_finder)

			total_count = filtering_finder.count
			limit_override = child_row_limit_override(child_name)
			filtered_ids = []

			# When limit override is active, we won't filter - just display the first n records
			if !limit_override.nil?
				# Total count outside the filter
				total_count = filtering_finder.count
				filtered_ids = filtering_finder.limit(limit_override).map{|r| r.id}
			else
				# No limit override active - filter the records and grab the top n
				limit = child_row_limit
				(0..total_count-1).each do |i|
					r = filtering_finder[i]
					break if filtered_ids.length >= limit
					filtered_ids << r.id if r.show_in_child_list?
				end
			end

			# Full load
			all = complete_finder.find(filtered_ids)
			return {:objects => all, :total_count => total_count}
		end

		# Child records to show on the show screen. Relationship name to options hash. Options hash includes:
		# - build_on_new: integer, how many blank child records to initialize on a new parent record
		# - show_in_table: boolean, show child records in table format? (default: false)
		# - build_if_missing: boolean, always ensure at least one child is available on new or edit
		# - no_add_button
		# - attrs: attributes to show (in the same format as attrs_for_form), if different than default
		# - label: the heading to appear before each kind of children
		def children_for_form
			{}
		end

		# Additional actions linked to from the show page. Should return a Proc which accepts the resource and returns a hash containing :action and :method members.
		def additional_show_actions
			nil
		end

		# Array of model attributes to not show anywhere.
		def filter_attributes
			[:id]
		end

		def only_on_show_attributes
			[:created_at, :updated_at]
		end

		# Actions to take when initializing a new resource (e.g. default values)
		def before_new(resource)
		end

		# Hash of available filters. Filter name (maps to parameter name) to options hash. Options hash consists of:
		# - label
		# - type: :boolean, :string, or a model class
		# - values: hash or array as would be passed to options_for_select
		# - size: for string input, the max size of the input
		# Either type or values must be provided, but not both.
		def available_filters
			{}
		end

		# Overwrite to apply filters - check the params and set "where"s and such on the finder. Should also call filter_title.
		def apply_filters(finder)
			finder
		end

		def filters_active?
			!(params.keys.map{|k|k.to_s} & available_filters.keys.map{|k|k.to_s}).empty?
		end

		# Array of available report names. Controller must implement generate_report_(name), which returns a hash with:
		# - description (optional)
		# - rows - 2D array of data
		def available_reports
			[]
		end

		# Array of available views. Each entry is a hash containing label and action.
		def available_views
			[]
		end

		###
		# Methods for translating between model and controller. Works automatically given reasonable naming conventions.
		###

		def model_class
			get_model_for_controller(self.class)
		end

		def model_name
			model_class.name.to_s
		end

		def get_controller_for_model(model_name)
			create_controller((model_name.to_s.pluralize.camelize + 'Controller').constantize)
		end

		def create_controller(klass)
			c = klass.new
			c.request = request
			return c
		end

		def get_model_for_controller(cls)
			cls.name.sub(/Controller$/, '').singularize.camelize.constantize
		end

		def get_model_class(attr)
			model_class.get_model_class(attr)
		end

		def get_controller_for_attr(resource, attr_name)
			matching_rels = model_class.reflect_on_all_associations.select{|a| a.name == attr_name.to_sym}
			if matching_rels.empty?
				# not a relationship - get an object and see what it is
				vals = resource.send(attr_name)
				return nil if vals.empty?
				return get_controller_for_model(vals.first.class.name)
			end
			matching_rel = matching_rels.first
			class_name = matching_rel.options[:class_name]
			class_name = attr_name if class_name.nil?
			return get_controller_for_model(class_name)
		end

		###
		# Actions
		###

		def index
			@autocomplete_filter_values = {}
			@resources = apply_filters(model_class.all)
			@resources = dexee_user.apply_filters(controller_name, @resources)
			@additional_values = additional_index_values
			respond_with(@resources, @additional_values) do |format|
				format.html {
					@resources = index_lookup_chain(@resources.includes(includes_for_index)).paginate(:page => params[:page], :per_page => index_per_page)
				}
				format.xlsx {
					# all records is too much in many cases - limit to 2000
					@resources = @resources.limit(2000)
					@resources = export_lookup_chain(@resources.includes(includes_for_export))
					Axlsx::Package.new do |p|
						p.workbook.add_worksheet(:name => model_class.to_s.titlecase.pluralize) do |sheet|
							attrs = attrs_for_export
							# header
							header_style = sheet.styles.add_style({:b => true})
							sheet.add_row attrs.map{|k,opts|opts[:label].nil? ? k.to_s.titlecase : opts[:label]}, :style => header_style
							# data
							# get type of each row so we only need to calculate once, logic based on
							# https://github.com/randym/axlsx/blob/master/lib/axlsx/workbook/worksheet/cell.rb#L423
							attr_types = excel_data_types(@resources, @additional_values, attrs)
							@resources.each do |r|
								sheet.add_row attrs.map{|a,opts|display_attr(r, a, false, @additional_values[r.id], nil, true)}, {:types => attr_types}
							end
							# freeze panes
							sheet.sheet_view.pane do |pane|
								pane.top_left_cell = attrs[1] == :reference_number ? 'C2' : 'B2'
								pane.state = :frozen_split
								pane.y_split = 1
								pane.x_split = attrs[1] == :reference_number ? 2 : 1
								pane.active_pane = :bottom_right
							end
						end
						send_data p.to_stream.read, :filename => "#{model_class.to_s.titlecase.pluralize}.xlsx", :type => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
					end
				}
			end
		end

		def excel_data_types(resources, additional_values, attrs)
			# Find a resource with this attribute as non-nil so we can see what it is
			attrs.map {|a, opts|
				next opts[:type] if [:date, :time, :float, :integer, :string, :boolean, :iso_8601].include?(opts[:type])
				value_lookups = [a]
				# If it ends with _id, look up the model instead
				value_lookups.unshift(a.to_s.sub(/_id$/, '').to_sym) if a.to_s.ends_with?('_id')
				first_value = nil
				value_lookups.each do |v|
					first_resource_with_value = resources.find { |r| !nested_lookup(r, a).nil? }
					first_value = nested_lookup(first_resource_with_value, a) unless first_resource_with_value.nil?
					break if !first_value.nil?
					# Look in the additional values too
					first_value = additional_values.values.first[a] if !additional_values.nil? and !additional_values.empty?
					break if !first_value.nil?
				end
				next excel_data_type(first_value)
			}
		end

		def excel_data_type(v)
			return :string if v.nil?
			if v.is_a?(Date)
				:date
			elsif v.is_a?(Time)
				:time
			elsif v.is_a?(TrueClass) || v.is_a?(FalseClass)
				:boolean
			elsif v.is_a?(CrudModel)
				:string
			elsif v.is_a?(Integer) or v.to_s =~ /\A[+-]?\d+?\Z/
				:integer
			elsif v.is_a?(Float) or v.is_a?(BigDecimal) or v.to_s =~ /\A[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?\Z/
				:float
			elsif v.to_s =~ /\A(-?(?:[1-9][0-9]*)?[0-9]{4})-(1[0-2]|0[1-9])-(3[0-1]|0[1-9]|[1-2][0-9])T(2[0-3]|[0-1][0-9]):([0-5][0-9]):([0-5][0-9])(\.[0-9]+)?(Z|[+-](?:2[0-3]|[0-1][0-9]):[0-5][0-9])?\Z/
				:iso_8601
			else
				:string
			end
		end

		def new
			@return_to = params[:return_to]
			@resource = model_class.new
			children_for_form.each do |k, v|
				c = @resource.send(k)
				if c.is_a?(ActiveRecord::Associations::CollectionProxy)
					number_to_build = v[:build_if_missing] ? 1 : 0
					number_to_build = v[:build_on_new] if !v[:build_on_new].nil?
					number_to_build.times {
						c = @resource.send(k).build
						get_controller_for_model(c.class).before_new(c)
					}
				elsif c.nil? and v[:build_if_missing]
					@resource.send("build_#{k}")
				end
			end
			@resource.assign_attributes(permitted_params)
			before_new(@resource)
			dexee_user.before_new_resource(@resource)
			@association_children = all_association_children(@resource)
			respond_with(@resource)
		end

		def show
			# JSON doesn't need all the includes
			if params[:format] == 'json'
				@resource = model_class.find(params[:id])
				@additional_values = []
			else
				@resource = show_lookup_chain(model_class.includes(includes_for_show)).find(params[:id])
				if children_for_show.keys.any?{|attr| !@resource.respond_to?(attr)}
					@additional_values = additional_index_values[@resource.id]
				else
					@additional_values = []
				end
				@other_children = {}
				alternate_children_for_show_lookups.each do |key, proc|
					@other_children[key] = proc.call(@resource)
				end
			end
			if dexee_user.can_access_model(@resource)
				show_respond(@resource, @additional_values)
			else
				render :text => 'You don\'t have access to see this resource.', :status => 403
			end
		end

		def show_respond(resource, additional_values)
			respond_with(resource, additional_values) do |format|
				format.json { render json: resource.to_json }
			end
		end

		def create
			@return_to = params[:return_to]

			#@resource = model_class.create(permitted_params)
			@resource = model_class.new(permitted_params)
			before_save(@resource)
			if dexee_user.can_update_model(@resource)
				@resource.save
			else
				render :text => 'You don\'t have access to create this resource with the values you selected.', :status => 403
				return
			end

			@association_children = all_association_children(@resource)
			respond_with(@resource, :location => @return_to)
		end

		def edit
			@return_to = params[:return_to]
			@resource = model_class.find(params[:id])
			children_for_form.each do |k, v|
				if v[:build_if_missing]
					c = @resource.send(k)
					if c.is_a?(ActiveRecord::Associations::CollectionProxy)
						c = @resource.send(k).build
					elsif c.nil?
						c = @resource.send("build_#{k}")
					end
					get_controller_for_model(c.class).before_new(c)
				end
			end
			@association_children = all_association_children(@resource)
			if dexee_user.can_access_model(@resource)
				respond_with(@resource)
			else
				render :text => 'You don\'t have access to edit this resource.', :status => 403
			end
		end

		def update
			@return_to = params[:return_to]
			@resource = model_class.find(params[:id])

			# Before we update, is this something the user can touch?
			if !dexee_user.can_update_model(@resource)
				render :text => 'You don\'t have access to update this resource.', :status => 403
				return
			end

			# After we update, is it still something the user can touch?
			# This is the implemention of update, but with our user check
			# @resource.update(permitted_params)
			@resource.with_transaction_returning_status do
				@resource.assign_attributes(permitted_params)
				before_save(@resource)
				if dexee_user.can_update_model(@resource)
					@resource.save
				else
					render :text => 'You don\'t have access to make the changes you made to this resource.', :status => 403
					return
				end
			end

			@association_children = all_association_children(@resource)
			respond_with(@resource, :location => @return_to)
		end

		def show_delete_in_list?
			true
		end

		def destroy
			resource = model_class.find(params[:id])
			if !dexee_user.can_update_model(resource)
				render :text => 'You don\'t have access to delete this resource.', :status => 403
				return
			end
			if resource.destroy
				flash[:notice] = "#{model_name.to_s.underscore.humanize} #{resource.display_text} deleted."
			else
				flash[:alert] = resource.errors.full_messages.join('. ')
			end
			redirect_to params[:return_to] || request.referer
		end

		def before_save(resource)
		end

		# To add a report, override available_reports to return an array of report names. Then define
		# generate_report_(report_name). This should return a Hash:
		#
		# -header_partial: partial to put at the top of the form (for controls and such)
		# -options: currently selected options (Hash)
		# -tables: Array of Hashes containing columns, rows, footer, and description as described below.
		#          Use this when there are multiple datasets to include on a single report.
		# -columns: Array of column names or single-valued Hashes of column name to options. Options can have
		#           keys:
		#             -:label
		#             -:type
		#             -:model_attribute - the attribute to display models as
		#             -:wrap - allow wrapping? default: true
		# -rows: Array of:
		#           Hashes with keys matching columns, or
		#           Hashes of :header, :rows, and :footer, both containing Arrays of Hashes with keys matching columns (for inline headers and footers)
		# -footer: Array of Hashes with keys matching columns
		# -description: Description of report
		# -combined: if providing multiple tables, whether they should be combined into one HTML table (with 
		#            one column label row). Default: false.
		def report
			raise 'Unavailable' if !available_reports.include?(params[:report_name].to_sym)
			@data = self.send("generate_report_#{params[:report_name]}", params[:format] || 'html')
			respond_with(@data) do |format|
				format.xlsx {
					Axlsx::Package.new do |p|
						p.workbook.add_worksheet(:name => "Report") do |sheet|
							@data[:combined] = false if @data[:combined].nil?
							tables = @data[:tables].nil? ? [@data] : @data[:tables]
							tables.each_with_index do |table, table_index|
								sheet.add_row [table[:description]] if !table[:description].nil? && !@data[:combined]
								if table_index == 0 || !@data[:combined]
									sheet.add_row table[:columns].map{|v|
										next v.values.first[:label] || v.keys.first.to_s.titlecase if v.is_a?(Hash)
										next v.to_s.titlecase
									}
								end
								sheet.add_row [table[:description]] if !table[:description].nil? && @data[:combined]
								table[:rows].each do |d|
									# Do we have a header and rows?
									if d.is_a?(Hash) && !d[:header].nil?
										sheet.add_row report_row(table[:columns], d[:header])
									end
									if d.is_a?(Hash) && d.has_key?(:rows)
										rows = d[:rows]
									elsif d.is_a?(Array)
										rows = d
									else
										rows = [d]
									end
									rows.each do |row|
										sheet.add_row report_row(table[:columns], row)
									end
									if d.is_a?(Hash) && !d[:footer].nil?
										sheet.add_row report_row(table[:columns], d[:footer])
									end
								end
								if !table[:footer].nil? and !table[:footer].empty?
									table[:footer] = [table[:footer]] unless table[:footer].is_a?(Array)
									table[:footer].each do |row|
										sheet.add_row report_row(table[:columns], row)
									end
								end
							end
						end
						send_data p.to_stream.read, :filename => "#{params[:report_name]}.xlsx", :type => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
						
					end
					#send_data @data[:rows].to_xlsx.to_stream.read, :filename => "#{params[:report_name]}.xlsx", :type => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
				}
				format.pdf {
					handle_pdf('crud/report.html.erb', 'report.pdf', 'Seed-Ex Report', @data[:landscape] || false, {:options_partial => @data[:header_partial]})
				}
				format.html {
					# Default to text view
					params[:view] = 'text' if params[:view].nil?
					@title_override = "#{model_name.to_s.pluralize.underscore.humanize.titlecase} - #{params[:report_name].to_s.humanize.titlecase} Report"
					handle_pdf('crud/report.html.erb', 'report.pdf', 'Seed-Ex Report', @data[:landscape] || false, {:options_partial => 'crud/report_header', :additional_actions => {'Excel' => params.except(:view).merge(:format => 'xlsx')}})
				}
			end
		end

		def report_row(columns, row)
			return columns.map do |column|
				if column.is_a?(Hash)
					key = column.keys.first
					options = column.values.first
				else
					key = column
					options = {}
				end
				next display_value(row[key])
			end
		end

		def generate_report
			raise 'Not implemented'
		end

		def autocomplete_list
			# only alphanums count as starts of words
			search_strings = params[:query].split(/\s+/).select{|w| /\A[[:alnum:]].*/ =~ w} - model_class.non_autocomplete_fields

			# search by string
			resources = model_class.limit(50)
			# all the strings must be present on any of the fields
			search_strings.each do |s|
				condition_string = model_class.search_fields.map{|sf| "#{sf.to_s} regexp ?"}.join(' or ')
				# match the start of words, because that's how people will search
				resources = resources.where([condition_string].concat(["[[:<:]]#{Regexp.escape(s)}"] * model_class.search_fields.length))
				# Add references - any field with a .
				model_class.search_fields.select{|sf|sf.to_s.include?('.')}.each{|sf| resources = resources.references(sf.to_s.split('.').first)}
			end
			resources = autocomplete_lookup_chain(resources)
			render :json => {:suggestions => format_for_autocomplete(resources)}
		end

		# Map an array of resources into an array of hashes of data, value, highlight. Override to load additional info
		# on the resources, if necessary.
		def format_for_autocomplete(resources)
			return resources.map{|r| {:data => r.id, :value => r.form_display_text, :highlight => r.highlight_in_autocomplete}}
		end

		def child_form
			@resource = model_class.new
			@child_name = params[:name]
			@child_index = params[:index]
			@child_index = 0 if @child_index.nil?
			@resource.send(@child_name).build
			@format = params[:format]
			@attrs = children_for_form[@child_name.to_sym][:attrs]
			render :layout => false
		end

		def log
			@resource = model_class.find(params[model_name.foreign_key])
			@activities = PublicActivity::Activity.where(:trackable_type => model_name).where(:trackable_id => params[model_name.foreign_key])
		end

		###
		# Misc.
		###

		def permitted_attributes
			pa = []
			attrs_for_form.each{|attr, opts|
				fields = opts[:fields] || {attr => opts}
				fields.each{|a, o|
					if o[:association]
						pa << (a.to_s + '_id').to_sym
						next
					end
					if o[:compound]
						pa << {(a.to_s + '_attributes').to_sym => o[:compound]}
						next
					end
					pa << a
				}
			}
			associate_attrs, edit_attrs = children_for_form.partition{|a, opts| child_is_association(a)}
			edit_attrs.each do |cff, opts|
				attrs = get_controller_for_model(get_model_class(cff)).permitted_attributes
				attrs << :id
				pa << {(cff.to_s + '_attributes').to_sym => attrs}
			end

			associate_attrs.each do |a, opts|
				pa << {(a.to_s.singularize + '_ids').to_sym => []}
			end
			return pa
		end

		def permitted_params
			# Required model name or nothing
			params.fetch(model_name.underscore.to_sym, {}).permit(permitted_attributes)
		end

		def inverse_attribute(model_class, attr)
			return model_class.reflect_on_association(attr).inverse_of
		end

		def show_new_child_link(attr)
			# "through" stuff requires an intervening model
			association = model_class.reflect_on_all_associations.find{|a| a.name == attr.to_sym}
			return false if association.nil?
			return !association.options.has_key?(:through)
		end

		# Custom new child link
		def generate_new_child_link(resource, attr)
			nil
		end

		# Returns true if the attr is an association (many to many) rather than an actual child
		def child_is_association(attr)
			return !model_class.reflect_on_all_associations(:has_and_belongs_to_many).select{|a| a.name == attr.to_sym}.empty?
		end

		# Children to show for potential associations for all attributes.
		def all_association_children(resource)
			h = {}
			children_for_show.keys.select{|c| child_is_association(c)}.each{|c|
				h[c] = association_children(resource, c)
			}
			return h
		end

		# Children to show for potential associations for a particular attribute.
		def association_children(resource, attr_name)
			[]
		end

		def all_attrs_except(exceptions, return_hash = false)
			attrs = model_class.attribute_names.map {|a| a.to_sym}
			attrs = attrs - exceptions
			return attrs if !return_hash
			return attrs.each_with_object({}) { |v,h|
				h[v] = {}
				h[v][:type] = :numeric if model_class.columns_hash[v.to_s].cast_type.is_a?(ActiveRecord::Type::Integer) && !v.to_s.ends_with?('_id')
				h[v][:label] = label_overrides[v] if label_overrides.has_key?(v)
			}
		end

		# Return an array of attribute (symbol) to label to use for that attribute.
		def label_overrides
			{}
		end

		# Insert keys at a position in a hash
		# hash - existing hash
		# insertion_reference_key - key in the existing hash
		# before - if true, new entries will be inserted before the reference
		# insert_hash - entries to insert
		def hash_insert(hash, insertion_reference_key, before, insert_hash)
			r = {}
			hash.each do |k, v|
				r[k] = v if !before
				if (k == insertion_reference_key)
					insert_hash.each do |ik, iv|
						r[ik] = iv
					end
				end
				r[k] = v if before
			end
			return r
		end

		def filter_title(pre_adjs = [], post_adjs = [])
			if !pre_adjs.empty? or !post_adjs.empty?
				@title = (pre_adjs.join(' ') + ' ' + model_class.to_s.pluralize.underscore.humanize.titlecase + ' ' + post_adjs.join(' '))
				@title[0] = @title[0].capitalize
			end
		end

		def render_pdf_content
			return params[:format] == 'pdf' || params[:view] == 'text'
		end

		def handle_pdf(template, file_name, email_subject, landscape = false, options = {})
			orientation = landscape ? 'Landscape' : 'Portrait'
			if params[:email]
				# Activates wicked_pdf stylesheet tag in pdf.html.erb
				params[:format] = 'pdf'

				pdf = WickedPdf.new.pdf_from_string(render_to_string('dexee/crud/pdf', :layout => false, :locals => {:template => template}), :encoding => 'UTF-8', :print_media_type => true, :orientation => orientation)
				GenericMailer.dexee_email(params[:to], dexee_user.dexee_email, dexee_user.dexee_email, email_subject, params[:body], [{:name => file_name, :mime_type => 'application/pdf', :content => pdf}], dexee_user).deliver_now
				flash[:notice] = 'E-mail sent.'
				redirect_to({:controller => params[:controller], :action => params[:action], :id => params[:id]})
				return
			end

			respond_to do |format|
				format.html do
					render 'pdf', :locals => options.merge({:template => template})
				end
				format.pdf do
					render :pdf => file_name, :template => 'dexee/crud/pdf', :formats => 'html', :encoding => 'UTF-8', :print_media_type => true, :orientation => orientation, :locals => {:template => template}
				end
			end

		end

		def restrict_by_controller
			render :text => 'You don\'t have access to that.', :layout => false, :status => 403 unless dexee_user.can_access_controller(controller_name) || action_name == 'autocomplete_list'
		end

	end
end
