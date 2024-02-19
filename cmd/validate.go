package cmd

import (
	"fmt"
	"log"
	"os/exec"

	"github.com/Masterminds/semver/v3"
	"github.com/spf13/cobra"
	"golang.org/x/exp/slices"
)

func init() {
	rootCmd.AddCommand(validateCmd)
}

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validates userinput, sshConfiguration and GitConfiguration",
	Run: func(cmd *cobra.Command, args []string) {

		gitConfiguration := validateGitConfiguration()
		fmt.Printf("%s", gitConfiguration)
		validateSshConfiguration()
		validateUserInput()
	},
}

func validateGitConfiguration() map[string]string {

	var gitConfiguration = make(map[string]string)

	gitConfiguration["user"] = readGitConfiguration("user.name")
	gitConfiguration["email"] = readGitConfiguration("user.email")
	gitConfiguration["gpgformat"] = readGitConfiguration("gpg.format")
	gitConfiguration["gpgsign"] = readGitConfiguration("commit.gpgsign")
	gitConfiguration["tagsign"] = readGitConfiguration("tag.gpgsign")
	gitConfiguration["signingkey"] = readGitConfiguration("user.signingkey")

	return gitConfiguration
}

func readGitConfiguration(setting string) string {

	out, err := exec.Command("git", "config", "--get", setting).Output()
	if err != nil {
		fmt.Printf("Git config: Value for %s not set. Please check your git config: (git config --get %s).\n", setting, setting)
		log.Fatal(err)
	}
	return string(out[:])
}

func validateSshConfiguration() {

	out, err := exec.Command("ssh-add", "-l").Output()
	if err != nil {
		fmt.Printf("SSH config: ssh-add check failed. Maybe try 'eval $(ssh-agent -s)' to run agent, ssh-add -l to check added identities.\n")
		log.Fatal(string(out[:]), err)
	}
}

func validateUserInput() {

	out, err := exec.Command("git", "branch", "--show-current").Output()
	if err != nil {
		fmt.Printf("Failed git branch --show-current, it seems you are not running this from a Git enabled directory.\n")
		log.Fatal(err)
	}
	currentBranch := string(out[:])

	//fmt.Printf(currentBranch + opts.branchname)
	if branchnameArg != "" && branchnameArg != currentBranch {

		fmt.Printf("To help avoid misfortunes with Git Push, run the script from same branch you will push to. To push, actively set -b /--git-branch-name option.\n")
		fmt.Printf("You are running the script from checkout branch: %s and would like to push to: %s\n,", currentBranch, branchnameArg)
		log.Fatal(err)
	}

	if nexttagArg != "" {
		version, err := semver.NewVersion(nexttagArg)
		if err != nil {

			fmt.Printf("Input Tag %s is invalid semver (vV)'x.y.z(-prerelease)(+build)'.\n", nexttagArg)
			log.Fatal(err)
		}
		versionArg = version
	}

	scopes := []string{"minor", "patch", "major", "pre-release"}
	projecttypes := []string{"mvn", "gradle", "npm", ""}

	if semverscopeArg != "" {
		if !slices.Contains(scopes, semverscopeArg) {
			fmt.Printf("Option -s / --semver-scope must be <patch|minor|major>, was %s.\n", semverscopeArg)
			log.Fatal(err)
		}
	}

	if projecttypeArg != "" {
		if !slices.Contains(projecttypes, projecttypeArg) {
			fmt.Printf("Option -p / --project-type must be <mvn|npm|gradle> or empty, was %s.\n", projecttypeArg)
			log.Fatal(err)
		}
	}
}
