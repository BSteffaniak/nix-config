# question-prompt-preview

Companion extension for `@rwese/pi-question`.

This extension adds question-tool authoring guidance to Pi's system prompt so the model keeps `questions[].prompt` short and prints long context as normal assistant text before opening the question UI.

If the `question` tool still receives a prompt estimated to exceed the upstream UI's 7-line preview, this extension shows the full prompt as a passive widget above the question UI. It does not replace or patch the upstream tool.

Diff-ish lines get lightweight coloring, and the fallback widget is cleared when the question tool finishes.
