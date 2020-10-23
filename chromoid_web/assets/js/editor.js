import css from "../css/editor.css"
import * as monaco from 'monaco-editor'
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
var decorations = [];

window.saveScript = function (content, callback) {
  console.log("Saving script")
  var xhr = new XMLHttpRequest();
  var formData = new FormData();
  var json;
  xhr.open("PUT", "/scripts/" + window.script.id + "/save", true);
  formData.append("content", content);
  formData.append("_csrf_token", csrfToken);
  console.dir(callback)

  xhr.onreadystatechange = (e) => {
    // request is complete
    if (xhr.readyState == 4) {
      if (xhr.status == 200) {
        console.log("Script save complete. response: ")
        console.log(xhr.responseText)
        callback(JSON.parse(xhr.responseText))
      } else if (xhr.status == 400) {
        console.log("Script save failed. response: ")
        console.log(xhr.responseText)
        callback(JSON.parse(xhr.responseText))
      }
    }
  }

  xhr.send(formData);
}

var editor = monaco.editor.create(document.getElementById('container'), {
  value: window.script.content || "",
  theme: "vs-dark",
  language: 'lua',
});
editor.addAction({
  // An unique identifier of the contributed action.
  id: 'save-hijack',

  // A label of the action that will be presented to the user.
  label: 'Save Script',

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
  run: function (ed) {
    saveScript(ed.getValue(), function (response) {
      if (response.errors) {
        response.errors.map(function (value, index, array) {
          if (value.type == "parse") {
            decorations = editor.deltaDecorations(decorations, [
              { range: new monaco.Range(value.line, 1, value.line, 1000), options: { inlineClassName: 'myInlineDecoration' } }
            ]);
          }
        })
      } else {
        decorations = editor.deltaDecorations(decorations, [])
      }
    });
    return null;
  }
});
