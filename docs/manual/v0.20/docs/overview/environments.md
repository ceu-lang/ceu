## Environments

As a reactive language, Céu depends on an external host platform, known as
*environment*, which determines the `input` and `output` events programs can
use.

An environment senses the world and broadcasts `input` events to programs.
It also intercepts emits on `output` events from programs to actuate in the
world:

![](environment.png)

As examples of typical environments, an embedded system may provide button
input and LED output, and a video game engine may provide keyboard input and
video output.
