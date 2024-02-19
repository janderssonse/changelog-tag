/*
Copyright © 2023 NAME HERE <EMAIL ADDRESS>
*/
package cmd

import (
	"fmt"
	"os"

	"github.com/Masterminds/semver/v3"
	"github.com/spf13/cobra"
)

var (
	semverscopeArg   string
	nexttagArg       string
	projecttypeArg   string
	branchnameArg    string
	repositoryurlArg string
	commitmessageArg string
	isAutomodeArg    bool
	versionArg       *semver.Version

	rootCmd = &cobra.Command{
		Use:   "changelogtag",
		Short: "An opinionated helper util for creating release commits with Changelog and project version bump.",
		Long: `
Changelogtag is a CLI utility that helps you generate a changelog,
and bump your project version. All in one release commit.

It honors standards like the Keep-A-Changelog-format,
SemVer and Conventional Commits.

Briefly, it:

	calculates and tags with next semver tag
	generates a changelog 
	updates the project file version with the version tag, if applicable.
	commits the changelog and tag in a nice release commit
	pushes the commit

All steps optional!`,

		Run: func(cmd *cobra.Command, args []string) {

			if isAutomodeArg {
				fmt.Println("Running in non-interactive (auto) mode.--help for options.")
			}
			validateCmd.Run(cmd, []string{""})
			identifyCmd.Run(cmd, []string{""})
			pro := cmd.Context().Value("iden").(Projectmeta)
			println("bbove")
			fmt.Printf("%+v", pro)
			println("above")
			nextVersionCmd.Run(cmd, []string{""})
			generateCmd.Run(cmd, []string{""})
			bumpCmd.Run(cmd, []string{""})
			commitChangelogCmd.Run(cmd, []string{""})
			//				pushReleaseCommitCmd.Run(cmd, []string{""})
			os.Exit(0)
			//cmd.Help()
		},
	}
)

func Execute() {
	err := rootCmd.Execute()
	if err != nil {
		os.Exit(1)
	}
}

func init() {
	//TO-DO cobra.onIntialize? Check for dependencies

	// Here you will define your flags and configuration settings.
	// Cobra supports persistent flags, which, if defined here,
	// will be global for your application.

	// rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.changelog-tag.yaml)")

	// Cobra also supports local flags, which will only run
	// when this action is called directly.

	//	rootCmd.Flags().BoolP("toggle", "t", false, "Help message for toggle")
	rootCmd.PersistentFlags().BoolVarP(&isAutomodeArg, "auto-mode", "a", false, "default: true")
	rootCmd.PersistentFlags().StringVarP(&semverscopeArg, "semver-scope", "s", "patch", "Semver scope for next tag when autoidentify <major|minor|patch>. Default: patch")
	rootCmd.PersistentFlags().StringVarP(&nexttagArg, "next-tag", "t", "", "Explictly decide next tag. (Discards autoidentify next tag)")
	rootCmd.PersistentFlags().StringVarP(&projecttypeArg, "project-type", "p", "", "Explictly set project type <npm|mvn|gradle|none>. (Discards autoidentify project type")
	rootCmd.PersistentFlags().StringVarP(&branchnameArg, "git-branch-name", "b", "", "Git branch name to push to (any_name). Must be current working branch")
	rootCmd.PersistentFlags().StringVarP(&repositoryurlArg, "repository-url", "r", "", "Full repository url. Default: autoidentify from git remote url.")
	rootCmd.PersistentFlags().StringVarP(&commitmessageArg, "commit-message", "m", "", "Release commit message. Default: chore: release v<tag>.")

}
