# PCOS CARE - Android app (APK) - what to do

You do NOT need to install anything on your laptop. GitHub builds the app for you, free.

1. Make a free account at https://github.com (skip if you have one).
2. Click "+" (top right) > "New repository". Name it `pcos-care`. Click "Create repository".
3. Unzip `pcos_care_app.zip`. On the new repository page click "uploading an existing file".
   Drag EVERYTHING inside the unzipped folder (pubspec.yaml, the `lib` folder, the `.github` folder, README)
   into the page. Click "Commit changes".
   (If the `.github` folder does not upload: in the repo click Add file > Create new file, type
   `.github/workflows/build.yml` as the name, paste the contents of `build_workflow_backup.yml`, commit.)
4. Open the "Actions" tab. A run called "Build Android APK" starts by itself. Wait 5-10 minutes for a green tick.
   (No run? Click "Build Android APK" on the left > "Run workflow".)
5. Click the finished run. At the bottom, under "Artifacts", click `pcos-care-apk` to download.
   Unzip it: inside is `app-release.apk`.
6. Send `app-release.apk` to your phone (USB cable, Google Drive, or email to yourself).
7. On the phone, tap the file. If asked, allow "Install unknown apps" for that app (Files/Chrome/Drive). Tap Install.
   Open "PCOS CARE" from your app drawer. No browser, no URL.

If step 4 shows a red cross: open the failed run, copy the red error text, and send it to me. I will fix it.
