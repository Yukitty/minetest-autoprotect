Autoprotect
===========
**Minetest** 0.4.10 mod *autoprotect* by JTE.
Released under the MIT license (see *[LICENSE](https://github.com/Yukitty/minetest-autoprotect/blob/master/LICENSE)* for details)

This module is a collection of scripts which are intended to provide the following services to your Minetest game:
* Spawn area protection within a given radius, to protect newcomers and allow grief-proof permanent server-owned structures to be built.
* Easily accessible dynamic layered 2D protection areas which every user can allocate to fit their constructs. User-friendly two dimensional area selection, server-friendly vertical protection limits suitable for layered worlds.
* Extended protection which not only blocks other users from digging or placing blocks directly, but also invasively protects and prevents interface access and other block usages automatically, even for blocks from other mods.
* Even external non-player entities which manipulate blocks are denied entry into protected areas thanks to invasive extensions made specifically for the builtin falling_node and external mesecons mods.

This is currently alpha software. It is not functionally complete and should not be used on public servers.
Currently missing features include:
* Protection areas are not yet checked for overlaps.
* Protection areas cannot be re-selected and modified once finalized and deselected, although they can be modified immediately after being placed.
* There are no visualizations for protection areas, nor any active notification for crossing into one.
* Users are not checked for exceeding their protection area limits.
* More support for various mods may be required.

Anyone is free to use or contribute to this software as they see fit.
