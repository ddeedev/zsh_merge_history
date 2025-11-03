package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// HistoryEntry represents a zsh history command with timestamp and duration
type HistoryEntry struct {
	Command  string
	Time     int64
	Duration int
}

// CommandMap maps commands to their most recent history entry
type CommandMap map[string]HistoryEntry

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "Usage: %s <history_files...>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "Example: %s zsh_history_*.bak ~/.zsh_history > merged_zsh_history\n", os.Args[0])
		os.Exit(1)
	}

	multilineCommand := fmt.Sprintf("TO_BE_REMOVED_%d", time.Now().Unix())
	commands := make(CommandMap)

	// Sort the file arguments
	files := os.Args[1:]
	sort.Strings(files)

	// Compile regex patterns
	multilineRegex := regexp.MustCompile(`\\\n(?!:\s*\d{10,})`)
	validLineRegex := regexp.MustCompile(`^: \d{10,}:\d+;`)

	for _, histFile := range files {
		fmt.Fprintf(os.Stderr, "Parsing '%s'\n", histFile)

		if err := processHistoryFile(histFile, multilineCommand, multilineRegex, validLineRegex, commands); err != nil {
			log.Fatalf("Error processing %s: %v", histFile, err)
		}
	}

	// Output merged commands sorted by timestamp
	outputMergedCommands(commands, multilineCommand)
}

func processHistoryFile(filename, multilineCommand string, multilineRegex, validLineRegex *regexp.Regexp, commands CommandMap) error {
	file, err := os.Open(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// Read entire file content
	content, err := readFileContent(file)
	if err != nil {
		return err
	}

	// Replace multiline command continuations
	content = multilineRegex.ReplaceAllString(content, multilineCommand)

	// Validate all lines follow zsh history format
	lines := strings.Split(content, "\n")
	var problematicLines []string

	for _, line := range lines {
		if line != "" && !validLineRegex.MatchString(line) {
			problematicLines = append(problematicLines, line)
		}
	}

	if len(problematicLines) > 0 {
		return fmt.Errorf("problem with those lines: %v", problematicLines)
	}

	// Process each line
	for _, line := range lines {
		if line == "" {
			continue
		}

		entry, err := parseHistoryLine(line)
		if err != nil {
			return fmt.Errorf("error parsing line '%s': %v", line, err)
		}

		// Keep the most recent entry for each command
		if existing, exists := commands[entry.Command]; !exists || entry.Time > existing.Time {
			commands[entry.Command] = entry
		}
	}

	return nil
}

func readFileContent(file *os.File) (string, error) {
	var content strings.Builder
	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		content.WriteString(scanner.Text())
		content.WriteString("\n")
	}

	if err := scanner.Err(); err != nil {
		return "", err
	}

	return content.String(), nil
}

func parseHistoryLine(line string) (HistoryEntry, error) {
	// Split on first semicolon to separate timestamp from command
	parts := strings.SplitN(line, ";", 2)
	if len(parts) != 2 {
		return HistoryEntry{}, fmt.Errorf("invalid history line format")
	}

	description := parts[0]
	command := parts[1]

	// Parse timestamp: ": timestamp:duration"
	timeParts := strings.Split(description, ":")
	if len(timeParts) != 3 || timeParts[0] != "" || timeParts[1] == "" {
		return HistoryEntry{}, fmt.Errorf("invalid timestamp format")
	}

	timestamp, err := strconv.ParseInt(timeParts[1], 10, 64)
	if err != nil {
		return HistoryEntry{}, fmt.Errorf("invalid timestamp: %v", err)
	}

	duration, err := strconv.Atoi(timeParts[2])
	if err != nil {
		return HistoryEntry{}, fmt.Errorf("invalid duration: %v", err)
	}

	return HistoryEntry{
		Command:  command,
		Time:     timestamp,
		Duration: duration,
	}, nil
}

func outputMergedCommands(commands CommandMap, multilineCommand string) {
	// Convert map to slice for sorting
	var entries []HistoryEntry
	for _, entry := range commands {
		entries = append(entries, entry)
	}

	// Sort by timestamp
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Time < entries[j].Time
	})

	// Output in zsh history format
	for _, entry := range entries {
		// Restore multiline commands
		command := strings.ReplaceAll(entry.Command, multilineCommand, "\\\n")
		fmt.Printf(":%11d:%d;%s\n", entry.Time, entry.Duration, command)
	}
}
