# `Firebase Test Lab` Plugin for fastlane

This project is a [fastlane](https://fastlane.tools) plugin. You can add it to your [fastlane](https://fastlane.tools) project by running

```bash
fastlane add_plugin firebase_test_lab
```

## About Firebase Test Lab plugin

[Firebase Test Lab](https://firebase.google.com/docs/test-lab/) let you easily test your iOS and Android app on a variety of real or virtual devices and configurations with just one API call. This plugin allows you to submit your app to Firebase Test Lab by adding an action into Fastfile.

## Getting started

### If you are not current user of Firebase
You need to set up Firebase first. These only needs to be done once for an organization.

- If you have not used Google Cloud before, you need to [create a new Google Cloud project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#Creating%20a%20Project) first.
- Go to the [Firebase Console](https://console.firebase.google.com/), to add Firebase into your Google Cloud project.

### Limitation on using this plugin during Firebase Test Lab iOS beta
Since iOS support on Firebase Test Lab is in beta, only Firebase [Flame and Blaze Plan](https://firebase.google.com/pricing/) are currently supported by this plugin. If you are on Spark plan, you can still use [Firebase Console](https://firebase.google.com/firebase-console) to test your iOS apps.

### Configure Google credentials through service accounts
To authenticate, Google Cloud credentials will need to be set for any machine where fastlane and this plugin runs on.

If you are running this plugin on Google Cloud [Compute Engine](https://cloud.google.com/compute), [Kubernetes Engine](https://cloud.google.com/kubernetes-engine) or [App Engine flexible environment](https://cloud.google.com/appengine/docs/flexible/), a default service account is automatically provisioned. You will not need to create a service account. See [this](https://cloud.google.com/compute/docs/access/service-accounts#compute_engine_default_service_account) for more details.

In all other cases, you would need to configure the service account manually. You can follow [this guide](https://cloud.google.com/docs/authentication/getting-started) on how to create a new service account. You will need to set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable according to the document.

No matter you are a using an automatically provisioned service account or a manually created one, the service account must be configured to have project editor role.

### Enable relevant Google APIs
- You need to enable the following APIs on your [Google Cloud API library](https://console.cloud.google.com/apis/library) (see [this](https://support.google.com/cloud/answer/6158841) for how):
  1. Cloud Testing API
  2. Cloud Tool Results API
  3. Service Management API

### Find out the devices you want to test on
If you have [gcloud tool](https://cloud.google.com/sdk/gcloud/), you can run

```bash
gcloud beta firebase test ios models list
```
This will return a list of supported devices and their identifiers.

All available devices can also be seen [here](https://firebase.google.com/docs/test-lab/ios/available-testing-devices). 


## Actions

### firebase_test_lab_ios_xctest

Submit your iOS app to Firebase Test Lab and run XCTest
```ruby
scan(
  project: 'YourApp.xcodeproj',       # Path to the Xcode project file
  scheme: 'YourApp',                  # XCTest scheme
  sdk: 'iphoneos',                    # Required
  should_zip_build_products: true     # Must be true to set the correct format for Firebase Test Lab
)
firebase_test_lab_ios_xctest(
  gcp_project: 'your-google-project', # Your Google Cloud project name
  devices: [                          # Device(s) to run tests on
    {
      iosModelId: 'iphonex',          # Device model ID, use gcloud command above
      iosVersionId: '11.2',           # iOS version ID, use gcloud command above
      locale: 'en_US',                # Optional: default to en_US if not set
      orientation: 'portrait'         # Optional: default to portrait if not set
    }
  ]
)
```

Arguments available are:

- `app_path` You may provide a different path in the local filesystem (e.g: `/path/to/app-bundle.zip`) or on Google Cloud Storage (`gs://your-bucket/path/to/app-bundle.zip`) that points to an app bundle as specified [here](https://firebase.google.com/docs/test-lab/ios/command-line#build_xctests_for_your_app). If a Google Cloud Storage path is used, the service account must have read access to such file.
- `gcp_project` The Google Cloud project name for Firebase Test Lab to run on.
- `oauth_key_file_path` The path to the Google Cloud service account key. If not set, the default credential will be used.
- `async` If set to true, the action will not wait for the test results but exit immediately.
- `timeout_sec` After how long will the test be abandoned by Firebase Test Lab. Duration hould be given in seconds.
- `result_storage` Designate which location on Google Cloud Storage to store the test results. This should be a directory (e.g: `gs://your-bucket/tests/`)

## Issues and Feedback

If you have any other issues and feedback about this plugin, we appreciate if you could submit an issue to this repository.

## Troubleshooting

For some more detailed help with plugins problems, check out the [Plugins Troubleshooting](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/PluginsTroubleshooting.md) doc in the main `fastlane` repo.

## Using `fastlane` Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://github.com/fastlane/fastlane/blob/master/fastlane/docs/Plugins.md) in the main `fastlane` repo.

## About `fastlane`

`fastlane` automates building, testing, and releasing your app for beta and app store distributions. To learn more about `fastlane`, check out [fastlane.tools](https://fastlane.tools).
