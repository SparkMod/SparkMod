This is an initial alpha release of the SparkMod framework, there is already a lot of useful core functionality implemented and more will be added over time. As with any alpha, limited testing has been done so bugs are to be expected, you can report any issues you may come across using the GitHub issue tracker.

## Server Admins
SparkMod provides many useful features for server admins, a few base server plugins are included with the framework and more will be added in the near future.

## Mod Developers
SparkMod provides an abstracted plugin environment for the Spark engine and NS2 modding. It aims to make development of server-side and client-side plugins as quick and easy as possible, allowing developers to focus on implementing their mods functionality rather than spending time learning the existing game code and engine. Many of the features provided are inspired by SourceMod and some interfaces are similar to decrease the learning curve for those already familiar with SourceMod plugin development. String formatting is extended to allow use of the %N token for formatting a ServerClient or Player object as the players nickname, the %T and %t translation tokens are also supported for global and context based language translations. Server plugins can be loaded/reloaded at any time so that changes can be made and tested on the fly.

There is a basic [Introduction to writing your first plugin](https://github.com/SparkMod/SparkMod/wiki/Introduction) on the wiki, more tutorials and other important information will be added soon. API docs are a work in progress but many of the functions available to plugins are already documented. SparkMod API are hosted at: [http://sparkmod.github.io/api](http://sparkmod.github.io/api)

## Web Interface
You can even edit your plugin code and reload it using the web based editor available on the SparkMod tab that is intergrated into the standard NS2 Web interface. Some other improvements made to the web interface include, the addition of a red plug and loading animation which indicates when the connection to the server is lost or when the server is loading, and the mod browser has been reimplemented so that loading the web interface or using the mod browser does not make the entire game server lag. Additional features such as plugin management and server configuration will be added later.


## Installing SparkMod
SparkMod can be added to your server either by using the workshop mod id or by adding the line `Script.Load("lua/SparkMod/server.lua")` directly into the top of your Server.lua file (before the line `Script.Load("lua/Shared.lua")`). Note that all client-side modding capabilities will be unavailable unless you use the workshop mod id as that is the only way for clients to load mods.

There is a lot of cool functionality available so it will take a while to document it all. Keep an eye on this page, the wiki and the API docs.