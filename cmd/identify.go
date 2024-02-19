package cmd

import (
	"context"
	"fmt"
	"log"
	"os"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(identifyCmd)
}

type Projectmeta struct {
	filenames   []string
	projecttype string
}

var (
	identifyCmd = &cobra.Command{
		Use:   "identify",
		Short: "Identifies the projecttype",
		Run: func(cmd *cobra.Command, args []string) {
			projectmetaResult := getProjectType()
			fmt.Printf(projectmetaResult.projecttype)
			fmt.Println(projectmetaResult.filenames)
			ctx := context.WithValue(cmd.Context(), "iden", projectmetaResult)
			cmd.SetContext(ctx)
			//return projectmetaResult
		},
	}
)

func projectFilePath(filenames []string) ([]string, error) {

	var paths []string

	workingDir, err := os.Getwd()
	if err != nil {
		fmt.Println(err)
		log.Fatal(err)

	}

	for i := 0; i < len(filenames); i++ {
		if _, lerr := os.Stat(workingDir + "/" + filenames[i]); lerr == nil {
			paths = append(paths, workingDir+"/"+filenames[i])

			if lerr != nil {
				fmt.Print("Could not find projectfile %s\n", err)
			}
		}
	}
	return paths, err

}
func getProjectType() Projectmeta {

	var projectMetaData Projectmeta

	projectTypeMap := make(map[string][]string)
	projectTypeMap["mvn"] = append(projectTypeMap["mvn"], "pom.xml")
	projectTypeMap["npm"] = append(projectTypeMap["npm"], "package.json")
	projectTypeMap["npm"] = append(projectTypeMap["npm"], "package-lock.json")
	projectTypeMap["gradle"] = append(projectTypeMap["gradle"], "gradle.properties")

	projectfiles, ok := projectTypeMap[projecttypeArg]

	//arg was given and mapping was found
	if ok {
		shouldReturn, returnValue := lookupProjectType(projectfiles, projectMetaData)
		if shouldReturn {
			return returnValue
		}

	} else { //guess

		shouldReturn, returnValue := autoIdentifyProject(projectTypeMap, projectMetaData)
		if shouldReturn {
			return returnValue
		}
	}

	projectMetaData.filenames = append(projectMetaData.filenames, "A")
	projectMetaData.projecttype = "B"
	return projectMetaData
}

func lookupProjectType(projectfiles []string, projectMetaData Projectmeta) (bool, Projectmeta) {
	projectfilePaths, err := projectFilePath(projectfiles)
	projectMetaData.filenames = projectfilePaths
	projectMetaData.projecttype = projecttypeArg
	if err != nil {
		fmt.Print("Projectfile/s did not exist, projecttype: %s, path: %s", projecttypeArg, "todo")
		log.Fatal(err)
	} else {
		return true, projectMetaData
	}
	return false, Projectmeta{}
}

func autoIdentifyProject(projectTypeMap map[string][]string, projectMetaData Projectmeta) (bool, Projectmeta) {

	for projectTypeKey := range projectTypeMap {
		if projectFilePaths, perr := projectFilePath(projectTypeMap[projectTypeKey]); perr == nil {
			if len(projectFilePaths) != 0 {
				projectMetaData.filenames = projectFilePaths
				projectMetaData.projecttype = projectTypeKey
				return true, projectMetaData
			}
		}
	}
	return false, Projectmeta{}
}
