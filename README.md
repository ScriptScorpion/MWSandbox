# MWSandbox - is bash script that builds isolated environment to analyze behavior of the specified executable file

## Requirements

* all requirements are checked then you launch app

## Installation

1. Enter project directory and run: `chmod +x sandbox.sh`
2. run shell script: `./sandbox.sh`

## Configuration

**To allow system directories to be included in sandbox:**
1. open 'config.txt' file in project directory
2. write `set <directory>` to allow this directory to be accessible within sandbox (right now supported options are: `set proc`, `set dev`, `set etc`, `set sys`, `set var`)
