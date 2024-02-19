package cmd

import (
	"fmt"
	"log"
	"os/exec"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(pushReleaseCommitCmd)
}

var (
	pushReleaseCommitCmd = &cobra.Command{
		Use:   "pushReleaseCommti",
		Short: "commits a changelog",
		Long:  `Long validate description `,
		Run: func(cmd *cobra.Command, args []string) {
			pushReleaseCommit()

		},
	}
)

func pushReleaseCommit() {

	// if [[ "${APPLY_ACTION}" == 'y' ]]; then
	pushReleaseCommit()
	// else
	//    info "${YELLOW} Skipped git push of changelog and project file!${NC}"
	// fi
	if branchnameArg == "none" {

		fmt.Printf("${YELLOW}No Git branch was given (option -b | --git-branch-name). Skipping final Git push. ${NC}")
	} else if branchnameArg == "" {

		fmt.Printf("${YELLOW}INPUT_GIT_BRANCH_NAME was empty, skipping git push. Set branch with -b/--git-branch-name${NC}")
	} else {

		cmd := exec.Command("git", "push", "--atomic", "origin", branchnameArg, nexttagArg)
		stdin, err := cmd.StdinPipe()
		if err != nil {
			log.Fatal(err)
		}

		go func() {
			defer stdin.Close()
			//io.WriteString(stdin, "-al")
		}()

		_, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
			log.Fatal(err)
		}
	}

	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Git pushed tag and release commit to branch ${INPUT_GIT_BRANCH_NAME}")
}
