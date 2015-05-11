$(document).ready(function() {

	// Make Enter not submit forms!
	$('form.simple_form input:not([type="submit"])').on("keydown", function(e) {
		var code = e.keyCode || e.which; 
		if (code  == 13) {               
			e.preventDefault();
			return false;
		}
	});

	// Warn when navigating away
	$('form.simple_form').on("change", function(e) {
		e.target.form.setAttribute("data-dirty", "true");
	});
	$('form.simple_form').on("submit", function(e) {
		e.target.setAttribute("data-dirty", "false");
	});
	$(window).on('beforeunload', function() {
		if ($('form.simple_form[data-dirty="true"]').length > 0) {
			return "This should create a pop-up";
		}
	});

});
