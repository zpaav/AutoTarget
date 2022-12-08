# FFXI AutoTarget

An FFXI Windower 4 addon that targets the nearest enemy to you based on a target list and can automatically attack it.

This is a mashup addon using Lazy and Targeter. Not possible without either of these two code bases.
It has the engine of lazy with the targetting and set management of Targeter.
Lazy: https://github.com/tdk1069/Lazy
Targeter: https://github.com/xurion/ffxi-targeter

This is best used alongside healbot or some form of autows / autobuff management as I didn't want this to be more than targetting and attacking.

Requires addon: Shortcuts

*Note from Targeter: This is a work in progress. For some reason, there is a targeting delay in lag-prone areas such as Dynamis Divergence - I'll be looking into this to see if it can be fixed or improved, as server-side lag should have no real impact on this addon.*

## Load

`//lua load autotarget` loads up autotarget. Do not recommended this to be autoloaded with windower.

## Alias Note

`//atar <command>` and `//autotarget <command>` will do the same thing.

## Setting a target

`//atar add <target>` or `//atar a <target>` adds mandragora to the target list.

Example: `//atar add mandragora` or `//atar a mandragora` adds mandragora to the target list.

Running `//atar add` with no additional parameters will add the currently selected target to the target list.

## Pulltarget Action

`//atar pulltarget <action>` or `//atar pa <action>` will turn on the a feature to attempt to pull a target. Requires an action to fully work.

Actions can be made easier with shortcuts, example `//atar pa /dia`. You can try long form, but good luck on the formatting.

## Pulltarget

`//atar pulltarget <true|false>` or `//atar pt <true|false>` will turn on the a feature to attempt to pull a target. Requires an action to fully work.

## Setting the engine delay

`//atar enginedelay <number>` or `//atar delay <number>` will set the time between checks of doing something and pulling a new target.

Note: Lower engine delays may cause your char to try to pull multiple targets. Be reasonable. Timing in seconds. Default is 3.

## Setting the chat window display

`//atar addtochat <number>` - This is the chat window that the chatter is added to. Default is 11.

## Start Autotarget

This starts the auto targetting looking for closest mobs on your list.

`//atar <on|start>`

## Stop Autotarget

This stops the auto targetting and leaves the mobs alone.

`//atar <off|stop>`

## Target an enemy manually

`//atar target` or `//atar t` targets the nearest enemy to you from the target list.

## Removing a target

`//atar remove <target>` or `//atar r <target>` removes a target name from the target list.

Example: `//atar remove mandragora` or `//atar r mandragora` removes mandragora from the target list.

Running `//atar remove` no additional parameters will remove the currently selected target remove the target list.

## Removing all targets

`//atar removeall` or `//atar ra` removes all targets from the target list.

## Display the target list

`//atar list` or `//atar l`


## Debug Mode

`//atar debug <true|false>` or `//atar debug <true|false>` will turn on additional information in the set chat window for target tracking. Good tool to set that delay the way you are comfortable with.

## Display Autotarget help

`//atar` or `//atar help`

## Target sets

You can save sets of targets for future use. For example, you can set up a target set for Bhaflau Thickets JP / MLVL with the following:

```
//atar add locus wivre
//atar add locus colibri
//atar save thickets
```

In the future, use the following to switch to the saved set:

`//atar load thickets`