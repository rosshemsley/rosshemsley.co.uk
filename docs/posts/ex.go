package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
)

func main() {
	file := os.Args[1]

	err := readSomeJSON(file)
	if err != nil {
		log.Fatalf("Failed: %s", err)
	}
}

func readSomeJSON(file string) error {
	data, err := parseJSON(file)
	if err != nil {
		return err
	}

	fmt.Printf("file contains %d keys\n", len(data))

	return nil
}

func parseJSON(file string) (map[string]interface{}, error) {
	bs, err := ioutil.ReadFile(file)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}

	err = json.Unmarshal(bs, &result)
	if err != nil {
		return nil, err
	}

	return result, err
}
