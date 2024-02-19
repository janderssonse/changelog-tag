package cmd

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"regexp"
	"strings"

	"github.com/spf13/cobra"
)

func init() {
	rootCmd.AddCommand(bumpCmd)
}

var (
	bumpCmd = &cobra.Command{
		Use:   "bump",
		Short: "bumps a projectfile/s version",
		Long:  `Long validate description `,
		Run: func(cmd *cobra.Command, args []string) {

			pro := cmd.Context().Value("iden").(Projectmeta)
			updateProjectfileVersion(pro)

		},
	}
)

func updateGradleVersion() {
	dat, err := os.ReadFile("gradle.properties")
	check(err)
	datAsString := string(dat[:])
	reg := regexp.MustCompile("version=.*")
	replaced := reg.ReplaceAllString(datAsString, "version="+nexttagArg)
	os.WriteFile("gradle.properties", []byte(replaced), 0777)
	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Updated gradle.properties version to ${YELLOW}%s${NC}", nexttagArg)
}

func updateProjectfileVersion(projectMetaData Projectmeta) {

	if projectMetaData.projecttype == "mvn" {
		updatePomVersion()
	} else if projectMetaData.projecttype == "npm" {
		updateNpmVersion()
	} else if projectMetaData.projecttype == "gradle" {
		updateGradleVersion()
	} else {
		fmt.Printf("${YELLOW} Skipped project file version update, as there was no project type found.")
	}

}

func updateNpmVersion() {
	_, err := exec.Command("npm", "--no-git-tag-version", "--allow-same-version", "version", nexttagArg).Output()
	if err != nil {
		fmt.Printf("Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf")
		log.Fatal(err)
	}
	//repourl = string(out[:])
	fmt.Printf("${GREEN} ${CHECKMARK} ${NC} Updated package.json version to ${YELLOW}%s${NC}", nexttagArg)
}

func check(e error) {
	if e != nil {
		panic(e)
	}
}
func updatePomVersion() {
	println("in MVN")
	updatePomVersion2()
	// var pomPath string = "pom.xml" //todo
	// parsedPom, err := gopom.Parse(pomPath)
	// if err != nil {
	// 	log.Fatal(err)
	// }
	// // _, err := exec.Command("mvn", "-q", "versions:set", "-DnewVersion="+nexttagArg).Output()
	//
	// fmt.Println("Before")
	// v := parsedPom.Version
	// fmt.Printf(string(*v))
	// parsedPom.Version = &nexttagArg
	//
	// fmt.Println(parsedPom.Version)
	// if err != nil {
	// 	fmt.Printf("Something went wrong when running Git tag -s %s -m %s exiting. Verify your gpg or ssh signing Git signing conf", nexttagArg, commitmessageArg)
	// 	log.Fatal(err)
	// }

	fmt.Printf("GREEN} ${CHECKMARK} ${NC} Updated pom.xml version to ${YELLOW}%s{NC}", nexttagArg)
}

func updatePomVersion2() {

	version := `xml:"version"`
	file, err := os.Open("pom.xml")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	var buf bytes.Buffer
	decoder := xml.NewDecoder(file)
	encoder := xml.NewEncoder(&buf)

	for {
		token, err := decoder.Token()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Printf("error getting token: %v\n", err)
			break
		}

		switch v := token.(type) {
		case xml.StartElement:
			if v.Name.Local == "version" {
				if err = decoder.DecodeElement(&version, &v); err != nil {
					log.Fatal(err)
				}
				// modify the version value and encode the element back
				version = strings.TrimPrefix(nexttagArg, "v")
				if err = encoder.EncodeElement(version, v); err != nil {
					log.Fatal(err)
				}
				continue
			}
		}

		if err := encoder.EncodeToken(xml.CopyToken(token)); err != nil {
			log.Fatal(err)
		}
	}

	// must call flush, otherwise some elements will be missing

	if err := encoder.Flush(); err != nil {
		log.Fatal(err)
	}

	//fmt.Println(buf.String())
	//	https://github.com/golang/go/issues/7535

	pomString := buf.String()
	removeXMLNS(&pomString)
}

func removeXMLNS(pomXML *string) {
	xmlString := *pomXML

	// Split the XML content into lines
	lines := strings.Split(xmlString, "\n")

	isProjecTag := false

	var modifiedXML string

	for _, line := range lines {
		if strings.Contains(line, "<project ") {
			isProjecTag = true
		}

		if isProjecTag || !strings.Contains(line, "xmlns=") {
			modifiedXML += line + "\n"
		} else {
			modifiedXML += strings.Replace(line, " xmlns=\"http://maven.apache.org/POM/4.0.0\"", "", -1) + "\n"
		}

		isProjecTag = false
	}
	// Print the result
	fmt.Println(modifiedXML)
}
