# User Override Contract

Skill workflows describe the default way to perform a task. They do not become irrevocable instructions merely because an agent read or began following them.

A direct, explicit instruction from the user may override a skill's workflow. Within the scope the user clearly authorizes, the user may:

- skip remaining review or approval gates;
- authorize immediate execution in natural language without using a structured question control;
- replace an interactive workflow with autonomous execution;
- revise or withdraw an earlier approval; or
- instruct the agent not to use, or to stop using, a skill.

The latest clear user instruction controls when it conflicts with an earlier skill workflow. Do not claim that a skill cannot be unloaded, that reading it made its workflow permanently binding, or that natural-language authorization is invalid solely because it did not create an approval artifact.

Treat overrides narrowly. They authorize only the task, mutations, and external side effects the user clearly requested. If the override or its scope is ambiguous, ask one concise clarifying question or continue with the skill's default gates.

This contract does not override system or developer instructions, repository policy, tool permission requirements, credential requirements, or safety restrictions on destructive or otherwise high-risk operations.
