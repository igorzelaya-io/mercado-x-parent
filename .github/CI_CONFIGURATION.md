# MercadoX CI configuration

The reusable Maven workflow keeps credentials out of source control. Configure
shared values at **GitHub organization settings → Secrets and variables →
Actions**, then grant access only to the MercadoX repositories. A repository can
override an organization-level value in **Repository settings → Secrets and
variables → Actions**.

## Secrets

| Name | Purpose | Notes |
| --- | --- | --- |
| `PACKAGES_TOKEN` | Read and publish MercadoX Maven packages | GitHub PAT with `read:packages` and `write:packages`; the workflow falls back to its temporary `GITHUB_TOKEN` when possible. |
| `SONAR_TOKEN` | Submit analysis to SonarQube | Generate in SonarQube with Execute Analysis permission. Never store it in a POM or workflow file. |

GitHub injects `GITHUB_TOKEN`, `GITHUB_ACTOR`, and `GITHUB_REPOSITORY` for every
workflow run. They do not need to be created manually.

## Variables

| Name | Purpose | Required |
| --- | --- | --- |
| `SONAR_HOST_URL` | Base URL of a self-hosted SonarQube Server | Server only; leave empty for SonarQube Cloud. |
| `SONAR_ORGANIZATION` | SonarQube Cloud organization key | Cloud only. |
| `SONAR_PROJECT_KEY` | Project key for the repository | Optional; defaults to `owner_repository`. Set per repository if the project uses another key. |

When `SONAR_TOKEN` is absent, CI still runs the tests, generates JaCoCo XML/HTML,
and uploads the coverage artifact. Only the remote Sonar analysis is skipped.
When it is present, packaging waits for the Sonar quality gate and fails if that
gate fails.

## IDE analysis

Install **SonarQube for IDE** (formerly SonarLint) in IntelliJ IDEA or VS Code,
then bind each checkout to its corresponding SonarQube Server or SonarQube Cloud
project using Connected Mode. This synchronizes the server quality profile and
shows issues while editing; it does not generate CI coverage.
