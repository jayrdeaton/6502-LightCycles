6502-LightCycles
===============

Tron-style LightCycles for the A.C. Wright 6502 platform.

Two-player deterministic gameplay first, optional one-player AI later.

## Controls

Joystick primary, keyboard fallback. Player 1 defaults to joystick 1, with
WASD as a fallback; player 2 defaults to joystick 2, with the arrow keys
as a fallback. Whichever joystick is being touched wins outright each
poll; the keyboard only takes over when that player's joystick shows
nothing that poll (including when no GPIO card is fitted at all). This
matches the standard convention for two people sharing one keyboard: WASD
is the physical left-hand cluster, arrow keys are the physical right-hand
cluster, so the two players' hands don't collide.

- **Up/Down/Left/Right** (joystick 1) or **W/A/S/D** (keyboard): turn
  player 1's cycle
- **Up/Down/Left/Right** (joystick 2) or **arrow keys** (keyboard): turn
  player 2's cycle
- **A button** (either joystick) or **Space** (keyboard): on the title
  screen, starts the round; during play, pauses/resumes; after a round,
  returns to the title screen

A bike always advances forward every tick; turning only changes its
heading, so unlike Pong's paddles there's no need to hold a direction to
keep moving — the last direction pressed sticks until changed again.

On the title screen, player 1's Up/Down (joystick or W/S) picks one-player
or two-player mode, and each player independently cycles their own trail
color with Left/Right (joystick, or A/D for player 1 and the arrow keys
for player 2) — same joystick-first, keyboard-fallback priority as
in-game movement.

See PLAN.md for architecture, phases, and verification gates.

## License

The code is released under the MIT License, see [LICENSE](LICENSE).

The game's name, logo, and icons, and the original artwork and audio in this repository, are not covered by that license and remain all rights reserved. If you fork it, please give your version its own name and look.
