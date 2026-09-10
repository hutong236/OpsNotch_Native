# Proposal: Persistent menu-bar toggle host

## Problem
The v2.7.5 follow-up split the hiding spacer and `‹ / │` toggle into two `NSStatusItem`s. On real Macs, menu-bar restoration and dynamic width layout can still place the toggle on the hidden side of the spacer, so collapsing the real menu-bar area also hides the only reveal control.

## Change
Use one variable-width `NSStatusItem` host for the ordinary hidden section. The host contains a fixed-width `‹ / │` child button pinned to the edge nearest Ops Notch. The remaining host width acts as the hiding spacer.

## Goals
- Keep `‹ / │` visible and clickable in collapsed, expanded, and auto-hidden states.
- Preserve the user's existing menu-bar position by reusing the legacy hidden-separator autosave key on the host.
- Keep Ops Notch left click dedicated to the hidden-items proxy panel.
- Keep AX classification and notch overflow checks aligned with the host's hidden-side boundary.
- Do not modify Quick Shelf / stash behavior.

## Issue
Closes #72.
