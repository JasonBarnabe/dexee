$(document).ready(function() {
	$('.combobox-entry').each(function() {
		$(this).autocomplete({
			serviceUrl: $(this).attr('data-autocomplete-url'),
			autoSelectFirst: true,
			deferRequestBy: 250,
			formatResult: function(suggestion, currentValue) {
				// Bold the stuff that matches
				var v = suggestion.value;
				var currentWords = currentValue.trim().split(/\s+/)
				for (var i = 0; i < currentWords.length; i++) {
					var reWord = new RegExp("\\b" + currentWords[i].replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&'), "i");
					v = v.replace(reWord, "<b>$&</b>");
				}
				// Put a span that says if this should be highlighted
				return "<span class='" + (suggestion.highlight ? "autocomplete-highlight" : "autocomplete-no-highlight") + "'>" + v + "</span>";
			},
			onSelect: function(suggestion) {
				var changed = $(this).attr('data-selected-id') != suggestion.data;
				$(this).attr('data-selected-id', suggestion.data);
				if ($(this).attr('data-id-input') != null) {
					$(this).attr('data-selection-valid', "true");
					var dataIdE = $('#' + $(this).attr('data-id-input'));
					if (suggestion.data != dataIdE.val()) {
						dataIdE.val(suggestion.data);
						console.log("Triggering change from onSelect");
						dataIdE.trigger("change");
					}
				}
				if ($(this).attr('data-jump-url') != null) {
					var id = $(this).attr('data-selected-id');
					location.href = $(this).attr('data-jump-url').replace(/9{9}/, id);
					console.log("Setting ID");
				}
				if ($(this).hasClass("filter_autocomplete") && changed) {
					location.href = changeParam(location.href, this.name, $(this).attr('data-selected-id'));
				}
			},
			onInvalidateSelection: function() {
				$(this).attr('data-selected-id', null);
				console.log("Invalidate");
				if ($(this).attr('data-id-input') != null) {
					$(this).removeAttr('data-selection-valid');
					var dataIdE = $('#' + $(this).attr('data-id-input'));
					if (dataIdE != "") {
						dataIdE.val('');
						console.log("Triggering change from onInvalidateSelection");
						dataIdE.trigger("change");
					}
				}
			},
			onSearchComplete: function(query, suggestions) {
				if ($(this).attr("data-selection-pending") == "true") {
					console.log("Search complete, removing pending and selecting.");
					$(this).removeAttr('data-selection-pending');
					$(this).autocomplete().onSelect(0);
					if (document.activeElement != this) {
						console.log("Autocomplete element is no longer active, hiding results.");
						$(this).autocomplete().hide();
					}
				}
			},
			onSearchError: function() {
				console.log("Search failed.");
				$(this).removeAttr('data-selection-pending');
			}
		});
		if ($(this).attr('data-jump-url') != null) {
			$(this).keypress(function(e) {
				var id = $(this).attr('data-selected-id');
				if (id && e.which == 13) {
					location.href = $(this).attr('data-jump-url').replace(/9{9}/, id);
				} else {
					console.log("No ID yet");
				}
			});
		}
		if ($(this).hasClass("filter_autocomplete")) {
			$(this).keypress(function(e) {
				var id = $(this).attr('data-selected-id');
				if (id && e.which == 13) {
					location.href = changeParam(location.href, this.name, id);
				}
			});
		}
	});
	$('.combobox-entry').change(function() {
		if ($(this).autocomplete().currentRequest) {
			// User pressed enter, but we're not ready. We'll fire again when we are.
			console.log("Request pending, will select when complete.");
			$(this).attr("data-selection-pending", "true");
		} else if ($(this).attr('data-selection-valid') != "true") {
			$(this).val('');
			var dataIdE = $('#' + $(this).attr('data-id-input'));
			dataIdE.val('');
		}
	});
});
