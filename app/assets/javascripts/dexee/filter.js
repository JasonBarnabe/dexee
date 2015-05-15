$(document).ready(function() {

	function handleFilterChange(ev) {
		var el = ev.target;
		var name = el.name;
		var value = $(el).val();
		if (value ==  "") {
			value = null;
		}
		location.href = changeParam(location.href, name, value);
	}

	$('.filter_dropdown').each(function() {
		$(this).change(handleFilterChange);
	});
	$('.filter_input').each(function() {
		$(this).change(handleFilterChange);
		$(this).keypress(function (e) {
			if (e.which == 13) {
				handleFilterChange(e);
			}
		});
	});
	// autocomplete filter handled in autocomplete.js
});

function changeParam(startingUrl, name, value) {
	var urlParts = startingUrl.split('?')
	var params = [];
	if (urlParts.length > 1) {
		stringParams = urlParts[1].split("&");
		for (var i = 0; i < stringParams.length; i++) {
			var paramParts = stringParams[i].split("=")
			if (paramParts[0] != name) {
				params.push(paramParts);
			}
		}
	}
	if (value != null) {
		params.push([name, value]);
	}
	var paramString = "";
	var first = true;
	for (var i = 0; i < params.length; i++) {
		paramString += (first ? '?' : '&') + params[i][0] + "=" + params[i][1];
		first = false;
	}
	return urlParts[0] + paramString;
}
