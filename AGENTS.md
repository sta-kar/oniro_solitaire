# Every design decision must be approved by a user.

If you reach a point where you need to make a decision that can produce user-distinguishable apps, ask the user to make the decision. 
If you suspect that there is only one sensible choice you can suggest it to the user, but you still need to get his approval.

# Document the code.

Documnet the code and design decisions in ./docs

# Tool of choice is oniro-app CLI.

Use `oniro-app` to sign, build, install, launch and interact with your app. Use the emulator already running at 127.0.0.1:55555. 

# Don't do advanced interface testing by yourself.

Don't hesitate to ask the user for interacting with the app. General rule of thumb: if you need to run 3+ commands to do something in the app, just ask the user to do it.
