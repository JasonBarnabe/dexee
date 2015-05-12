class ComboboxInput < SimpleForm::Inputs::Base
	def input(wrapper_options)
		html = @builder.hidden_field(attribute_name.to_s + '_id')
		id = html.match(/ id="([^"]+)"/)[1]
		value = @builder.object.send(attribute_name)
		model_class = @builder.object.class.get_model_class(attribute_name)
		return "#{html}<input id='#{attribute_name.to_s}_compound' class='combobox-entry' data-id-input='#{id}' data-autocomplete-url='#{input_options[:autocomplete_url]}' value='#{value.nil? ? '' : value.form_display_text}' #{@required ? 'required' : ''}>".html_safe
	end
end
