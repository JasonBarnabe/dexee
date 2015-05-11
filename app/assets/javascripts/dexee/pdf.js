document.addEventListener("DOMContentLoaded", function() {
	var pdfIFrames = document.querySelectorAll("iframe.pdf-view");
	for (var i = 0; i < pdfIFrames.length; i++) {
		pdfIFrames[i].style.height = Math.max(600, $(document).height() - $(pdfIFrames[i]).position().top - 20) + 'px';
	}
	var printViewSwitches = document.querySelectorAll(".switch-view");
	for (var i = 0; i < printViewSwitches.length; i++) {
		printViewSwitches[i].addEventListener("click", function(event) {
			location.href = event.target.getAttribute("data-view-url");
		});
	}
});

function showEmailOptions() {
	document.getElementById("email-options").style.display = (document.getElementById("email-options").style.display == "block" ? "" : "block")
}
