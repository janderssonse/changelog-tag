package cmd

import (
	"fmt"
	"log"
	"os"
	"os/exec"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(commitChangelogCmd)
}

var (
	commitChangelogCmd = &cobra.Command{
		Use:   "commit",
		Short: "commit a changelog and projectfile",
		Long: `This command allows you commit either an 
		  changelog, projectfile or both.
		To default is to commit both of them,
		  or choose with -c or --changelog flag,
		  or -p or --project flag.
		Examples:
		./changelogtag commit
		./changelogtag commit --changelog
		./changelogtag commit --projectfile`,
		Run: func(cmd *cobra.Command, args []string) {
			pro := cmd.Context().Value("iden").(Projectmeta)
			commitChangelogAndProjectfile(pro)

		},
	}
)

func packageLockExists(filepath string) bool {
	if _, err := os.Stat(filepath); err == nil {
		return true
	} else {
		return false
	}
}
func commitChangelogAndProjectfile(p Projectmeta) {

	commitMsg := "chore: release ${NEXT_TAG}"
	_, err := exec.Command("git", "add", "CHANGELOG.md").Output()
	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
		log.Fatal(err)
	}

	// if opts
	//
	//  if [[ -n "${PROJECT_FILE}" ]]; then
	//
	//    git_add "${PROJECT_FILE}"
	//
	//    if [[ "${PROJECT_TYPE}" == 'npm' ]]; then
	//      local have_package_lock
	//      have_package_lock=$(package_lock_exists)
	//
	//      if [[ -n "${have_package_lock}" ]]; then
	//        git_add "${PROJECT_ROOT_FOLDER}package-lock.json"
	//      fi
	//    fi

	_, err = exec.Command("git", "commit", "-q", "--signoff", "--gpg-sign", "-m", commitMsg).Output()

	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
		log.Fatal(err)
	}

	// if [[ -n ${PROJECT_FILE} ]]; then
	//   info "${GREEN} ${CHECKMARK} ${NC} Added and committed ${YELLOW}CHANGELOG.md ${PROJECT_FILE}${NC}. Commit message: ${YELLOW}${commit_msg}${NC}"
	// else
	//   info "${GREEN} ${CHECKMARK} ${NC} Added and committed ${YELLOW}CHANGELOG.md${NC}. Commit message: ${YELLOW}${commit_msg}${NC}"
	// fi

	moveTagToReleaseCommit()
}
func moveTagToReleaseCommit() {

	out, err := exec.Command("git", "rev-parse", "HEAD").Output()

	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
		log.Fatal(err)
	}

	latestCommit := string(out[:])

	_, err = exec.Command("git", "tag", "-f", nexttagArg, latestCommit, "-m", nexttagArg).Output()

	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
		log.Fatal(err)
	}
	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Moved tag ${YELLOW}${NEXT_TAG}${NC} to latest commit ${YELLOW}${latest_commit}${NC}")
}
