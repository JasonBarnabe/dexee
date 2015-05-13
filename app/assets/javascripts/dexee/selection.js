$(document).ready(function() {
	$('.toggle-selected-checkboxes').click(function() {
		// figure out the start and end positions of the selection
		var sel = getSelection();
		if (sel.isCollapsed) {
			return;
		}
		var startNode = $(sel.anchorNode);
		var endNode = $(sel.focusNode);

		// if we're in a table row, assuming the whole row was selected
		startNode = parentRowOrSelf(startNode);
		endNode = parentRowOrSelf(endNode);

		var startPos = getPosition(startNode);
		var endPos = getPosition(endNode);

		// anchor is where the selection started, focus is where it ended. If someone selected upwards, swap them
		if (comparePos(startPos, endPos) == 1) {
			// Doesn't work in Chrome
			// [startPos, endPos] = [endPos, startPos];
			// [startNode, endNode] = [endNode, startNode];
			var tmpPos = startPos;
			startPos = endPos;
			endPos = tmpPos;
			var tmpNode = startNode;
			startNode = endNode;
			endNode = tmpNode;
		}

		// grab all checkboxes, then see if they fall within the start and end positions
		var afterStart = false;
		var checkboxes = $("input[type='checkbox']").each(function() {
			var el = $(this);
			var cPos = getPosition(el);
			// don't have to keep checking once we're after start since they'll be in order
			afterStart = afterStart || (comparePos(startPos, cPos) == -1)
			if (afterStart) {
				// if we're after end, stop! we'll toggle children of the end too.
				if (comparePos(endPos, cPos) == -1 && el.closest(endNode).length == 0) {
					return false;
				}
				el.prop("checked", !el.prop("checked"))
			}
		})
	});

	function parentRowOrSelf(node) {
		var trs = node.parents("tr");
		if (trs.length > 0) {
			return trs.first();
		}
		return node;
	}

	// Returns an array representing the position of the element in the document
	function getPosition(el) {
		var pos = []
		while (el.length > 0) {
			pos.unshift(el.index());
			el = el.parent();
		}
		return pos;
	}

	// Returns -1 if p1 is before p2
	function comparePos(p1, p2) {
		for (var i = 0; i < p1.length; i++) {
			// p1 is a child of p2
			if (!(i in p2)) {
				return 1;
			}
			if (p1[i] < p2[i]) {
				return -1;
			}
			if (p1[i] > p2[i]) {
				return 1;
			}
		}
		if (p2.length > p1.length) {
			// p2 is a child of p1
			return -1;
		}
		return 0;
	}

});
