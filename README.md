# Godot Rollback Netcode

This is an example of Rollback Netcode implemented in Godot with GDScript and Universal Plug and Play.
No port forwarding required! 

Major thanks to @SpiceyWolf for contributing to this project.

**PULL REQUESTS WELCOME**

Explanation of Rollback Netcode: https://ki.infil.net/w02-netcode.html

Basic Rollback Netcode Algorithm: https://gist.github.com/rcmagic/f8d76bca32b5609e85ab156db38387e9

Deeper Explanation (using code): http://blog.hypersect.com/rollback-networking-in-inversus/
## Local Testing

For testing on a single computer, you will want to have two different clients open at the same time. Make sure that they are both set to Local and make sure only **ONE** is set as Player One.

## Further Research

- Figure out how to do this with WebRTC
- Add more players
- Integrate fixed point libraries
  - Current plan is to create a fork of Box2D with the C++ Library fpm to make it deterministic and then make that a Godot module.

# Resources

## General Game Stuff

Introduction to State Machines:https://gameprogrammingpatterns.com/state.html

## General Networking:

Networked Physics:https://www.gafferongames.com/post/introduction_to_networked_physics/

Also the full website is pretty cool (General Networking Bible)https://gafferongames.com/

## Godot Networking:

Basic multiplayer documentation: https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html

Multiplayer Tutorials: Used to build the prototype[Files · master · menip / Godot Multiplayer Tutorials · GitLab](https://gitlab.com/menip/godot-multiplayer-tutorials/-/tree/master)

First video in a series on how to do dedicated servers in Godot.[Godot Multiplayer Server-Client Tutorial | Godot Dedicated Server #1 - YouTube](https://www.youtube.com/watch?v=lnFN6YabFKg)

Very minimalistic tutorial on how to set up a godot dedicated server.https://mrminimal.gitlab.io/2018/07/26/godot-dedicated-server-tutorial.html

NAT Holepunching Plugin: https://github.com/SLGamesCregg/HolePuncher

## General Godot Stuff:

How to format your gdscript code: https://github.com/Scony/godot-gdscript-toolkit

How to do camera on multiple people:https://www.youtube.com/watch?v=W7WsL3qaPqg

## FPS Networking:

Source Engine Networking (Valve):https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking

Overwatch Networking:https://www.youtube.com/watch?v=W3aieHjyNvw

Halo Reach Networking:https://www.youtube.com/watch?v=h47zZrqjgLc

Quake Cheats: http://www.catb.org/esr/writings/quake-cheats.html

Tribes Networking Model:https://www.gamedevs.org/uploads/tribes-networking-model.pdf

Extrapoliation/Dead Reckoning:https://www.gabrielgambetta.com/entity-interpolation.html

MMO Networking (I Think): http://ithare.com/contents-of-development-and-deployment-of-massively-multiplayer-games-from-social-games-to-mmofps-with-stock-exchanges-in-between/
