# The delivery map key

The app draws its map with the Google Maps SDK. The key is NOT in the repo:

* iOS — `ios/Flutter/Secrets.xcconfig` (git-ignored):

      GMS_API_KEY = AIza…

* Android — `android/local.properties` (git-ignored):

      googleMapsApiKey=AIza…

Use keys restricted in Google Cloud (project 932944071249): an iOS key limited to
the bundle `com.zooboxi.app`, an Android key limited to `com.zooboxi.app` + the
upload and Play signing SHA-1s, both limited to the Maps SDK for iOS / Android.
Without a key the map area stays blank; search and the address still work — they
go through the store (`/zooboxi/v2/location/search|place|resolve`), which holds
its own server key.
