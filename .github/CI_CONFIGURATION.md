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

Successful pushes to `develop`, `main`, or `master` publish Maven `SNAPSHOT`
artifacts. Downstream builds use Maven's `-U` flag so they refresh those
snapshots instead of silently using an older cached library. A branch build
never republishes a non-snapshot version.

## Immutable releases

Each repository releases independently by pushing a tag in the form `vX.Y.Z`.
The shared workflow rejects the release unless all of these conditions hold:

- the Maven project version is exactly `X.Y.Z` (without `-SNAPSHOT`);
- the Maven parent version is not a snapshot; and
- no resolved `hn.shadowcore` dependency is a snapshot.

Release libraries in dependency order: `mercado-x-parent`,
`mercado-x-library-entity`, `mercado-x-redis`, `mercado-x-context`, then
`mercado-x-library-jpa`. Services can be released after their required library
versions exist.

For each repository:

1. Change its project version, parent version, and internal dependency versions
   to the intended immutable releases.
2. Commit and push the change, then wait for CI to pass.
3. Create and push the matching tag, for example `git tag v1.0.0` followed by
   `git push origin v1.0.0`.
4. Confirm that the tag workflow published the Maven package.
5. Move the development branch to the next `-SNAPSHOT` version.

Do not reuse or move a release tag. To correct a released artifact, publish a
new patch version such as `1.0.1`.

### First stable library release

The initial immutable release set is:

| Maven coordinate | Version |
| --- | --- |
| `hn.shadowcore:mercado-x-parent` | `1.0.0` |
| `hn.shadowcore:mercado-x-library-entity` | `1.0.0` |
| `hn.shadowcore:mercado-x-redis` | `1.0.0` |
| `hn.shadowcore:mercado-x-context` | `1.0.0` |
| `hn.shadowcore:mercado-x-library-jpa` | `1.0.0` |

Publish each coordinate only once and in the dependency order above. After all
five packages exist, microservice development builds may remain snapshots while
pinning these shared dependencies to `1.0.0`.

## IDE analysis

Install **SonarQube for IDE** (formerly SonarLint) in IntelliJ IDEA or VS Code,
then bind each checkout to its corresponding SonarQube Server or SonarQube Cloud
project using Connected Mode. This synchronizes the server quality profile and
shows issues while editing; it does not generate CI coverage.
