# volleyball_rotation_app

A new Flutter project.

## Web Deployment

The `.github/workflows/deploy.yml` workflow builds and deploys the web app to
GitHub Pages on pushes to `main`. It can also be run manually from the Actions
tab using **Deploy Flutter Web to GitHub Pages > Run workflow**.

Before the first deployment, open the GitHub repository's **Settings > Pages**
and set **Build and deployment > Source** to **GitHub Actions**. Then commit
and push the source code, including the workflow and `pubspec.lock`.

The workflow uses Flutter 3.35.1, runs analysis and native tests, builds the web
app with the configured Pages base path, and publishes `build/web`. No local
build or additional repository secrets are needed. Keep `/build/` ignored.
Browser storage tests can be run separately with
`flutter test --platform chrome test/storage_web_test.dart`.

Rosters and rotations are stored in each browser's `localStorage`; they are
not shared between devices or copied from a localhost preview.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
