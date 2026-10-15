# Transferring the project through GitHub

No archive is created at the user's request. Transfer the project folder through your own GitHub repository.

1. Add `inex.rbxl`, `README_RU.md`, `src/`, `design/`, `tools/`, `assets/`, and `.gitignore` to the repository. `build/` contains intermediates/backups and is unnecessary to run the game.
2. On another PC, clone the repository or download it from GitHub. Extract downloaded files into an ordinary folder first.
3. Install Roblox Studio, open `inex.rbxl` through **File → Open from File**, and press **Play / F5**. Blender sources are unnecessary to run the game.
4. Model changes require Blender 5.2. Current `.blend` files are in `assets/blender/v012/base/`, `collection/`, and `decor/`.
5. To continue in a new chat, select this project folder and send the following text.

> Continue developing this Roblox game. First read design/NEXT_SESSION_RU.md, design/CONCEPT_RU.md, and design/ALL_FEATURES_RU.md. The main file is inex.rbxl. Discuss new mechanics and changes to agreed values with me first. Create models in Blender. Do not test every screen resolution. Explain the current state, then carry out my next request.

This transfers project files and working context. `NEXT_SESSION_RU.md` is a state handoff, not a verbatim chat transcript. Transfer the project folder separately from the chat link; access to the conversation alone does not put the local Roblox file on another computer.

`.gitignore` excludes `build/`, Studio lock files, temporary Blender copies, and Python caches. The main Roblox file and sources are not excluded. No repository was created or files uploaded on your behalf.
