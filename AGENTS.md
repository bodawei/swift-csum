Conversation
==
Do not summarize what you did.  This is usually telegraphed before doing it.  At most, just report what you did that wasn't in the original plan.

New system
===
- VS Code
- XCode
- OpenCode
- Claude Code
- Kimi Code
- Conductor
- Github CLI
- Chrome

New Repo
===
- Feature flagging?
- Otel system?

Code formatting
==
Do not add comments to any file

Always put a blank line before a `do` or `if` block, unless it is the first thing in a
parent block or function, and always put a blank line afterwards, unless it is the last
thing in a block or function.  Do the same around `switch` statements.

Do not repeat lines across the cases of a switch.  Factor the common lines out of the
cases.

Screenshots
==
Check screenshots that show a change into `images/changes/`, naming each for the change it
shows (e.g. `mac-table-headers-before.png`), and reference them from the PR description.
That is the preferred pattern for change screenshots.

Architecture
====
Layering
---
A canonical application should be thought of with possibly as many as 4 layers:
- View
    - For a GUI interface, part of the view is the actual view files which should just be the SwiftUI code with the only state in them is state that can be discarded when the view is torn down.  These are separate from...
    - For a GUI interface, the ViewModel is where the minimal state and behavior needed to support the view files lives.
    - For a CLI this is simply the access CLI to the "controller".
- Controller: this is where the bulk of the applications's data management and logic should reside. In essence, this is the application, just stripped of it's "head".
- Access: When there is a remote system, this layer may translate whatever API's the server provides into something more uniform for the Controller to consume.  In some cases, this may be a BFF running remotely.
- Remote system: When there is remote data or behavior, it lives here, in the remote server.  Probably owned by someone else.
  
To make this concrete:
|  | csum | iTango
| View | | |
| - View | SwiftUI | SwiftUI
| - ViewModel | event handlers and file dialog access, result caching | ?? |
| - CLI       | check and compare subcommands | ?? |
| Controller  | FS access, checksumming and diffing logic | ?? |
| Access  | N/A | TMLib |
| Rmote  | N/A | www.tangomango.org |
  

File mapping
---
The view and ViewModel may live together in one module (though, foldering is encouraged)
Each other layer should be in either a distinct folder or module, depending on its size


Testing
---
- "e2e" testing of application logic should happen through the CLI and the controller
- In a vibe coded world, we're more interested in "integration" testing of individual modules rather than unit testing (however, seriously complex files should have unit tests), e2e testing of logic and judicious e2e testing of the GUI.


Member access
==
Default member access to private unless there is a reason to give more access.


Naming
==
Name functions that do something with a verbal name.
