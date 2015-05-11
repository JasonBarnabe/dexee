$(document).ready(function() {
	$("input.datepicker").each(function(input) {
	  $(this).datepicker({
		dateFormat: "yy-mm-dd",
		altField: $(this).next()
	  })
	})
	$("input.datepicker-month").each(function(input) {
	  $(this).datepicker({
		dateFormat: "yy-mm",
		altField: $(this).next()
	  })
	})
})
