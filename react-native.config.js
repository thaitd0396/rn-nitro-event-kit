// https://github.com/react-native-community/cli/blob/main/docs/dependencies.md

module.exports = {
  dependency: {
    platforms: {
      /**
       * @type {import('@react-native-community/cli-types').IOSDependencyParams}
       */
      ios: {},
      // EventKit is an Apple framework and this package ships no android
      // sources, so declaring the platform would only give autolinking a
      // project that is not there.
      android: null,
    },
  },
}
