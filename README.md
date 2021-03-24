# Godot Rollback Netcode

This is an example of Rollback Netcode implemented in Godot with GDScript and Universal Plug and Play.
No port forwarding required! 

**PULL REQUESTS WELCOME**

Explanation of Rollback Netcode: https://ki.infil.net/w02-netcode.html

Basic Rollback Netcode Algorithm: https://gist.github.com/rcmagic/f8d76bca32b5609e85ab156db38387e9

## Local Testing

For testing on a single computer, you will want to have two different clients open at the same time. Make sure that they are both set to Local and make sure only **ONE** is set as Player One.

## Further Research

- Figure out how to do this with WebRTC
- Add more players
- Integrate fixed point libraries
  - Current plan is to create a fork of Box2D with the C++ Library fpm to make it deterministic and then make that a Godot module.