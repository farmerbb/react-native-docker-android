FROM gradle:6.0.1-jdk8

ENV DEBIAN_FRONTEND noninteractive

# Android & Gradle
ENV GRADLE_URL http://services.gradle.org/distributions/gradle-3.5-all.zip
ENV GRADLE_HOME /usr/local/gradle-6.0.1
ENV ANDROID_SDK_URL http://dl.google.com/android/android-sdk_r24.3.5-linux.tgz
ENV ANDROID_HOME /usr/local/android-sdk-linux
ENV ANDROID_SDK_COMPONENTS_LATEST platform-tools,build-tools-28.0.3,android-28,extra-android-support,extra-android-m2repository,extra-google-m2repository
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools

# NodeJS
ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION_NAME latest-dubnium
ENV NODE_VERSION 10.x

#Ruby
# https://www.ruby-lang.org/en/news/2020/03/31/ruby-2-7-1-released/
ENV RUBY_MAJOR 2.7
ENV RUBY_VERSION 2.7.1
ENV RUBY_DOWNLOAD_SHA256 b224f9844646cc92765df8288a46838511c1cec5b550d8874bd4686a904fcee7

ENV SDK_URL="https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip" \
    ANDROID_HOME="/usr/local/android-sdk" \
    ANDROID_VERSION=28 \
    ANDROID_BUILD_TOOLS_VERSION=28.0.3

ENV FASTLANE_VERSION 2.149.1

# Download Android SDK
RUN mkdir "$ANDROID_HOME" .android \
    && cd "$ANDROID_HOME" \
    && curl -o sdk.zip $SDK_URL \
    && unzip sdk.zip \
    && rm sdk.zip \
    && mkdir "$ANDROID_HOME/licenses" || true \
    && echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_HOME/licenses/android-sdk-license" \
    && yes | $ANDROID_HOME/tools/bin/sdkmanager --licenses

# Install Android Build Tool and Libraries
RUN $ANDROID_HOME/tools/bin/sdkmanager --update > /dev/null
RUN $ANDROID_HOME/tools/bin/sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    "platforms;android-${ANDROID_VERSION}" \
    "platform-tools"  > /dev/null

# Install Build Essentials
RUN apt-get update && apt-get install build-essential -y && apt-get install file -y && apt-get install apt-utils -y

RUN apt-get update && \
    apt-get -y install zip expect && \
    curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash - && \
    apt-get install -y nodejs

# install yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
    apt-get update && apt-get install -y yarn

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc

RUN set -ex \
  \
  && buildDeps=' \
    bison \
    libgdbm-dev \
    ruby \
    autoconf bison build-essential libssl-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev \
  ' \
  && apt-get install -y libtool libyaml-dev imagemagick \
  && apt-get install -y --no-install-recommends $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
  && echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
  && mkdir -p /usr/src/ruby \
  && tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
  && rm ruby.tar.xz \
  && cd /usr/src/ruby \
  # hack in "ENABLE_PATH_CHECK" disabling to suppress:
  #   warning: Insecure world writable dir
  && { \
    echo '#define ENABLE_PATH_CHECK 0'; \
    echo; \
    cat file.c; \
  } > file.c.new \
  && mv file.c.new file.c \
  \
  && autoconf \
  && ./configure --disable-install-doc --enable-shared \
  && make -j"$(nproc)" \
  && make install \
  \
  && cd / \
  && rm -r /usr/src/ruby \
  \
  && gem update --system

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
  BUNDLE_BIN="$GEM_HOME/bin" \
  BUNDLE_SILENCE_ROOT_WARNING=1 \
  BUNDLE_APP_CONFIG="$GEM_HOME"
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
  && chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

ENV RUBY_PATH "/usr/local/lib/ruby/gems/$RUBY_VERSION/bin"


# Path
ENV PATH $PATH:$BUNDLE_BIN:${ANDROID_HOME}/tools:$ANDROID_HOME/platform-tools:${GRADLE_HOME}/bin:$RUBY_PATH

RUN gem install fastlane -v ${FASTLANE_VERSION} \
  && gem install fastlane-plugin-appicon fastlane-plugin-android_change_string_app_name fastlane-plugin-humanable_build_number \
  && gem update --system
RUN gem install bundler

ENV APKINFO_TOOLS /opt/apktools
RUN mkdir ${APKINFO_TOOLS}
RUN wget -q https://github.com/google/bundletool/releases/download/0.10.3/bundletool-all-0.10.3.jar -O ${APKINFO_TOOLS}/bundletool.jar
RUN cd /opt \
    && wget -q https://dl.google.com/dl/android/maven2/com/android/tools/build/aapt2/3.5.0-5435860/aapt2-3.5.0-5435860-linux.jar -O aapt2.jar \
    && unzip -q aapt2.jar aapt2 -d ${APKINFO_TOOLS} \
    && rm aapt2.jar
RUN npm install -g react-native-cli

#firebase-tools setup
ADD https://github.com/firebase/firebase-tools/releases/download/v7.3.1/firebase-tools-linux firebase-tools-linux
RUN chmod +x firebase-tools-linux
RUN ./firebase-tools-linux --open-sesame appdistribution

ENV PATH $PATH:/usr/local/bundle/gems/fastlane-$FASTLANE_VERSION/bin/fastlane


# Remove Build Deps
RUN apt-get purge -y --auto-remove $buildDeps

# Output versions
RUN node -v && npm -v && ruby -v && fastlane -v && react-native -v
