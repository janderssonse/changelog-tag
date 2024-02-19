package cmd

import (
	"fmt"
	"log"
	"os/exec"
	"strings"

	"github.com/Masterminds/semver/v3"
	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(nextVersionCmd)
}

var (
	nextVersionCmd = &cobra.Command{
		Use:   "nextVersion",
		Short: "Identifies nextVersion",
		Long:  `Long validate description `,
		Run: func(cmd *cobra.Command, args []string) {

			calculateNextVersion()
		},
	}
)

func calculateNextVersion() {

	if nexttagArg == "" {

		out, err := exec.Command("git", "describe", "--abbrev=0", "--tags").Output()
		if err != nil {
			// fmt.Printf("Git config: %s not set. Please check your git config: (git config --get %s).\n")
			log.Fatal(err)
		}
		latestGitTag := string(out[:])
		latestGitTag = strings.TrimSuffix(latestGitTag, "\n")

		if latestGitTag == "" {
			latestGitTag = "v0.0.1"
			fmt.Printf("Could not find any existing tags in project. Default return v0.0.1\n")
		}

		fmt.Printf("... Calculating next tag from semver scope: ${YELLOW} %s\n", semverscopeArg)

		semVerVersion, err := semver.NewVersion(latestGitTag)
		//println(semVerVersion.String())
		if err != nil {

			fmt.Printf("Input Tag %s is invalid SemVer (vV)'x.y.z(-prerelease)(+build)'. Adhere to the SemVer-specification to use this tool.\n", latestGitTag)
			log.Fatal(err)
		}

		if semverscopeArg == "patch" {
			var nextVersion = semVerVersion.IncPatch()
			versionArg = &nextVersion
			nexttagArg = nextVersion.Original()

		}
		if semverscopeArg == "major" {
			var nextVersion = semVerVersion.IncMajor()
			versionArg = &nextVersion
			nexttagArg = nextVersion.Original()

		}
		if semverscopeArg == "minor" {
			var nextVersion = semVerVersion.IncMinor()
			versionArg = &nextVersion
			nexttagArg = nextVersion.Original()

		}
		if semverscopeArg == "pre-release" {
			var nextVersion = semVerVersion.IncPatch()
			versionArg = &nextVersion
			nexttagArg = nextVersion.Original()

		}

		fmt.Printf("$GREEN $CHECKMARK ${NC} Calculated next tag version as: ${YELLOW}%s${NC}. Current latest project tag is: ${YELLOW}%s${NC}\n", nexttagArg, latestGitTag)
	}
}
