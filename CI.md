# How CI is set up

## Generating signed builds

The [`check`](.github/workflows/check.yml) CI job creates a signed build of the app, and uploads it as an artifact.

We use [`match`](https://docs.fastlane.tools/actions/match/) to generate the code signing certificates and provisioning profiles. It stores this data, along with the corresponding private keys, in the private repository https://github.com/lawrence-forooghian/macdown-match.

The following GitHub repository secrets are also configured:

- `MATCH_REPOSITORY_ACCESS_TOKEN`: A fine-grained personal access token with access to the `lawrence-forooghian/macdown-match` repository, with "Contents: Read-only" permissions. This token belongs to the `lawrence-forooghian` GitHub account, and is named "MacDown CI code signing (match)".
- `MATCH_REPOSITORY_PASSWORD`: The password needed by `match` to decrypt the contents of the `lawrence-forooghian/macdown-match` repository.

## Generating notarized builds

My personal App Store Connect has an API key named "MacDown GitHub Actions", with Developer access. With this key, I used our `generate_app_store_connect_api_key` Fastlane lane to generate a key JSON file that Fastlane knows how to read.

The `APP_STORE_CONNECT_API_FASTLANE_KEY` GitHub repository secret contains this contents of this JSON file.
