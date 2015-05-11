$(document).ready(function() {
	$('.flyout-header').click(function() {
		$(this).parents('.flyout').toggleClass('open');
	});
});
