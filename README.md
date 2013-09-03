Meta repository to build Offline ToureNPlaner android application
=================================================================

You need:

  * [android sdk](http://developer.android.com/sdk/index.html), [android ndk](http://developer.android.com/tools/sdk/ndk/index.html)
  * wget
  * maven
  * ant
  * [cmake](http://www.cmake.org/), [ragel](http://www.complang.org/ragel/), (gnu) make

Building:
---------

3 steps:

  * Download 3rd party libs, sync git submodules: ``./download-dependencies.sh``
  * Compile dependencies: ``./build--dependencies.sh``
  * Compile, sign and zipalign android app: ``./build.sh``

(``build.sh`` looks for ``zipalign`` in ``${ANDROID_SDK:-/opt/android-sdk}/tools/zipalign`` and in the ``$PATH``)
