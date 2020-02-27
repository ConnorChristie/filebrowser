package main

import (
	"runtime"

	"github.com/ConnorChristie/filebrowser/v2/cmd"
)

func main() {
	runtime.GOMAXPROCS(runtime.NumCPU())
	cmd.Execute()
}
