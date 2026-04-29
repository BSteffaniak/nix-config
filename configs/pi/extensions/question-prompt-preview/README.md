# question-prompt-preview

Companion extension for `@rwese/pi-question`.

When the `question` tool receives a prompt estimated to exceed the upstream UI's 7-line preview, this extension shows the full prompt as a passive widget above the question UI. It does not replace or patch the upstream tool.

Diff-ish lines get lightweight coloring, and the widget is cleared when the question tool finishes.
