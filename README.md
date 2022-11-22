# Docker image for building React Native Android apps

This Docker image contains all dependencies required to build React Android apps
based on React Native and ensures that build happens in the clear environment.


# Building the image

You can rebuild it by issuing the following command:

```sh
NODE_VERSION=10.13.0 YARN_VERSION=1.10.1 ANDROID_SDK_VERSION=4333796 ANDROID_PLATFORM=27 BUILD_TOOLS_VERSION=28.0.3 make build
```

Optionally you can add the following variables:

* `REVISION=int`, which will add -0, -1, -2... suffix to the build image. If not 
  specified it is set to 0.
* `IMAGE=name`, which will override default image name. If not specified it is 
  set to `swmansion/react-native-android`.

## Versioning

The built image will have a docker tag of with version of the following syntax:

`NODE_VERSION-YARN_VERSION-ANDROID_SDK_VERSION-ANDROID_PLATFORM-BUILD_TOOLS_VERSION-REVISION`

It may look inconvenient to use but it allows you to refer to particular 
combination of versions if you're using CI.


# Sample usage

Typically if you want to invoke a build of a React Native app using that image
you should call the following commands from your application's directory:

Enter the image, while mounting application as `/app`:

```sh
docker run --rm -ti -v `pwd`:/app swmansion/react-native-android:10.13.0-1.10.1-4333796-27-28.0.3-0 bash
```

Inside the container, change the directory to the application's directory:

```sh
cd /app
```

Install dependencies:

```sh
yarn install
```

Invoke the actual build (debug build in such case):

```sh
react-native bundle --platform android --dev false --entry-file index.js --bundle-output android/app/src/main/assets/index.android.bundle --assets-dest android/app/src/main/res
cd android && ./gradlew assembleDebug
```

The .apk file will be located at `/app/android/app/build/outputs/apk/debug/app-debug.apk`


# Source & Pre-built images on Docker Hub

* https://hub.docker.com/r/swmansion/react-native-android

# Copyright and License

Licensed under the [Apache License, Version 2.0](LICENSE)
