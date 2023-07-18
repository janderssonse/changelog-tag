<!--
SPDX-FileCopyrightText: Josef Andersson

SPDX-License-Identifier: CC0-1.0
-->

# Changelog Tag

![GitHub tag (latest SemVer)](https://img.shields.io/github/v/tag/janderssonse/changelog-tag)

Making a nice release commit might indicate a few boring steps - adding a changelog, tagging, update project version. 

So why not .. A util script to make an atomic release commit including tag, changelog and updated Project file. Supports mvn, npm or gradle. 
Relies on Conventional Commits-standard. Sure!

Briefly, this script:

1. calculates and tags with next semver tag
2. generates a changelog in the Keep-A-Changelog-format, based on your Conventional Commits Git history.
3. updates the project file version with the version tag, if applicable.
4. commits the changelog and tag in a release commit
5. pushes the commit

All steps optional!

Quite early version, but useable.

## Table of Contents

- [Installation and Requirements](#installation-and-requirements)
- [Usage](#usage)
- [Known Issues](#known-issues)
- [Support](#support)
- [Contributing](#contributing)
- [Development](#development)
- [License](#license)
- [Maintainers](#maintainers)
- [Credits and References](#credits-and-references)

## Installation and Requirements

### Requirements

* Your project is (mostly) following the Conventional Commits Standard.
* Your Git Settings is configured to sign and tag with SSH.
* If you are not running the Snap, but go for the script directly, you will need a few dependencies. 

#### Running the script directly

- Clone this repo

```shell
git@github.com:janderssonse/changelog-tag.git
```

- Install needed dependencies. 
 
 A simple suggestion is to install the nice runtime version manager [asdf-vm](https://asdf-vm.com/guide/getting-started.html).

 Following are a few commands that adds the plugins and then installs them for you.
 
 _Note, it will set them globally in this example, but you can later switch versions with asdf, if needed for other projects, see the asdf-vm documentation._

```shell
# add asdf plugins from the asdf-vm .tool-versions file
$ cut -d' ' -f1 .tool-versions | xargs -i asdf plugin add {}

# install all listed .tool-versions plugins versions
$ asdf install

# pin the asdf versions
$ asdf global install git-chglog 0.15.4
$ asdf global install java adoptopenjdk-jre-17.0.7+7
$ asdf global install maven 3.8.8
$ asdf global install nodejs 20.4.0

```

- Finally, from the root dir of the project you are about to update a changelog to, do

```shell
/path/to/changelog-tagrepo/you/just/cloned/src/changelog_tag.sh --help
```

#### Running the Snap

Currently, the Snap is not published to the official store (not ready for prime time yet).
So, have a look under [Actions/Artifacts](https://github.com/janderssonse/changelog-tag/actions/)
and get the latest build.


As the Snap is not published on the official Snap store yet, you have to add --devmode flag.
I guess --dangerous would work as fine.

```shell
snap install --devmode ./changelog-tag_v0.0.1_amd64.snap
```

You also have to give the snap read-access to your Git configuration.

```shell
snap connect changelog-tag:gitconfig
snap connect changelog-tag:etc-gitconfig
```

Now, you can do an --help

```shell
changelog-tag --help
```

#### Running the Docker image

Currently not supported, work in progress. 

## Usage

A picture says more than a thousand words.

### Examples

<figure>
<img src="./docs/img/changelog_tag_cli.png " alt="changelog_tag cli" width="800"/>  
<figcaption><em>changelog_tag with --help option</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_tag_run.png " alt="changelog_tag run" width="800"/>  
<figcaption ><em>changelog_tag run</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_tag_log.png " alt="changelog_tag log" width="800"/>  
<figcaption><em>changelog_tag generated changelog example</em></figcaption>
</figure>

<figure>
<img src="./docs/img/changelog_tag_commit_example.png " alt="changelog_tag commit example" width="800"/>  
<figcaption><em>changelog_tag commit example - project file, changelog, tag and release commit message</em></figcaption>
</figure>

## Known issues

Roadmap:
- More choices regarding configuration
- Fully support prerelease and build options
- Rewrite in golang to ease maintenance etc
- Hope cogitto fixes the final bugs so this project can be deperacated
- See Issues for other ideas

## Support

If you have questions, concerns, bug reports, etc, please file an issue in this repository's Issue Tracker.

## Contributing

Please see [CONTRIBUTING](CONTRIBUTING.adoc).

## Development

### General style

- [Code style](https://google.github.io/styleguide/shellguide.html)

### Tests

The project uses the Bash test framework [Bats](https://github.com/bats-core/bats-core).

You can find a helper script for installing bats-core with dependencies in the (<projectdir>/development/):

```shell
./development/install_bats.sh
```
_Note: The bats files are installed under the `<projectdir>/development/lib`, not globally on on your system_

To run the tests:

```shell
./development/lib/bats/bin/bats src/test
```

### Linting the project

There is a script that checks code quality, commit history and license compliance. Please run that.
It is dependent on `podman`, and uses `megalinter`, `reuse-tool`, and `conform` to check for various aspects of quality.

```shell
./development/code_quality.sh
```
_Note: megalinter checks a lot of things, shellcheck etc, see the `development/mega-linter.yml` for enabled linters,_

----

## License

Licensed under the [GNU General Public License v3.0 or later](LICENSE).

Most other files are under CC0, but check the SPDX-headers if curious.

----

## Maintainers

[janderssonse](https://github.com/janderssonse)

## Credits and References

* [Git Changelog Generator](https://github.com/git-chglog/git-chglog)
* [The Bats project](https://github.com/bats-core/) - for making us create robust Bash-scripts.
* [Dannelof](https://github.com/danneleaf) - for the patch in an earlier incarnation of this util.
* [Digg](https://github.com/diggsweden) for some of the CC0 texts from their Open Source Project Template.