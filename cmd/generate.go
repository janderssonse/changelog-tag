package cmd

import (
	"errors"
	"fmt"
	"log"
	"os/exec"
	"strings"

	"path/filepath"
	"runtime"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(generateCmd)
}

var (
	generateCmd = &cobra.Command{
		Use:   "generate",
		Short: "Generates a changelog",
		Long:  `Long validate description `,
		Run: func(cmd *cobra.Command, args []string) {
			generateChangelog()

		},
	}
)

func generateChangelog() {

	if repositoryurlArg == "" {
		out, err := exec.Command("git", "config", "--get", "remote.origin.url").Output()
		if err != nil {
			fmt.Printf("Something went wrong when running Git config -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
			log.Fatal(err)
		}
		repositoryurlArg = string(out[:])

	}
	repositoryurlArg = strings.TrimSuffix(repositoryurlArg, ".git")
	repositoryurlArg = strings.Replace(repositoryurlArg, "git@gitlab.com:", "https://gitlab.com/", 1)
	repositoryurlArg = strings.Replace(repositoryurlArg, "git@github.com:", "https://github.com/", 1)

	runDir, _ := Dirname()
	gitChglogConfiguration := runDir + "/changelog_tag_templates/git-chglog-gl.yml"

	if strings.Contains(repositoryurlArg, "github") {

		gitChglogConfiguration = runDir + "/changelog_tag_templates/git-chglog-gh.yml"

	}

	println(runDir + " " + repositoryurlArg + " " + gitChglogConfiguration)
	_, err := exec.Command("git-chglog", "--repository-url", repositoryurlArg, "-c", gitChglogConfiguration, "-o", "CHANGELOG.md").Output()
	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s %s -m %s, exiting. Verify your gpg or ssh signing Git signing conf", nexttagArg, commitmessageArg)
		log.Fatal(err)
	}

	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Generated changelog as ${YELLOW}%s/CHANGELOG.md${NC}", runDir)
}

func Filename() (string, error) {
	_, filename, _, ok := runtime.Caller(1)
	if !ok {
		return "", errors.New("unable to get the current filename")
	}
	return filename, nil
}

// Dirname is the __dirname equivalent
func Dirname() (string, error) {
	filename, err := Filename()
	if err != nil {
		return "", err
	}
	return filepath.Dir(filename), nil
}
