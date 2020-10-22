import css from "../css/editor.css"

import { Socket } from "phoenix"
import * as monaco from 'monaco-editor'
console.log("HELLO!")
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

var editor = monaco.editor.create(document.getElementById('container'), {
  value: window.script.content || "",
  theme: "vs-dark",
  language: 'lua',
});
editor.addAction({
	// An unique identifier of the contributed action.
	id: 'my-unique-id',

	// A label of the action that will be presented to the user.
	label: 'My Label!!!',

	// An optional array of keybindings for the action.
	keybindings: [
		monaco.KeyMod.CtrlCmd | monaco.KeyCode.KEY_S,
	],

	// A precondition for this action.
	precondition: null,

	// A rule to evaluate on top of the precondition in order to dispatch the keybindings.
	keybindingContext: null,

	contextMenuGroupId: 'navigation',

	contextMenuOrder: 1.5,

	// Method that will be executed when the action is triggered.
	// @param editor The editor instance is passed in as a convinience
	run: function(ed) {

    var xhr = new XMLHttpRequest();
    var formData = new FormData();
    var method = "POST"

    if(window.script.id != "") {
      method = "PUT"
    }
    xhr.open(method, window.action, true);
    // formData.append("id", window.script.id);
    formData.append("name", document.getElementById("name").value);
    formData.append("content", ed.getValue());
    formData.append("_csrf_token", csrfToken);

    xhr.onreadystatechange = (e) => {
      console.log(xhr.responseText)
      if(xhr.status < 400) {
        json = JSON.parse(xhr.responseText);
        consold.log(json);
        console.log(xhr.responseText["id"])
        window.action = window.action + "/" + xhr.responseText["id"]
        window.script.id = xhr.responseText["id"]
      }
    }

    xhr.send(formData)

    // ed.deltaDecorations([], [
    //   { range: new monaco.Range(3,1,5,1), options: { isWholeLine: true, linesDecorationsClassName: 'myLineDecoration' }},
    //   { range: new monaco.Range(7,1,7,24), options: { inlineClassName: 'myInlineDecoration' }},
    // ]);
		return null;
	}
});