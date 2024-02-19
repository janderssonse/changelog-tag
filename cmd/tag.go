package cmd

import (
	"fmt"
	"log"
	"os/exec"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(tagCmd)
}

var (
	tagCmd = &cobra.Command{
		Use:   "nextVersion",
		Short: "Identifies nextversion",
		Long:  `Long validate description `,
		Run: func(cmd *cobra.Command, args []string) {

			if len(args) != 0 {

				tag(args[0], args[1])
				fmt.Println(args)
			}
		},
	}
)

func tag(theTag string, message string) {
	out, err := exec.Command("git", "tag", "-s", theTag, "-m", message).Output()

	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s %s -m %s, exiting. Verify your gpg or ssh signing Git signing configuration\n", theTag, message)
		fmt.Printf(string(out[:]))
		log.Fatal(err)
	}
	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Tagged (signed): ${YELLOW}%s${NC}", theTag)
}
