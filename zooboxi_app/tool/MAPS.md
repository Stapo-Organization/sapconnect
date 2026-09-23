# The delivery map key

The app draws its map with the Google Maps SDK. The key is NOT in the repo:

* iOS — `ios/Flutter/Secrets.xcconfig` (git-ignored):

      GMS_API_KEY = AIza…

* Android — `android/secrets.properties` (git-ignored). NOT local.properties:
  Flutter rewrites that file on every build and the key would vanish.

      googleMapsApiKey=AIza…

Check a bundle before uploading it — the manifest must carry the key:
`unzip -p app-release.aab base/manifest/AndroidManifest.xml | grep -c AIza` → 1.

Use keys restricted in Google Cloud (project 932944071249): an iOS key limited to
the bundle `com.zooboxi.app`, an Android key limited to `com.zooboxi.app` + the
upload and Play signing SHA-1s, both limited to the Maps SDK for iOS / Android.
Without a key the map area stays blank; search and the address still work — they
go through the store (`/zooboxi/v2/location/search|place|resolve`), which holds
its own server key.
