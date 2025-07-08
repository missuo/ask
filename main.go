package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

var version = "dev"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: ask <github-username>")
		fmt.Println("       ask search <query>")
		fmt.Println("       ask --version")
		os.Exit(1)
	}

	// Handle version flag
	if os.Args[1] == "--version" || os.Args[1] == "-v" {
		fmt.Printf("ask version %s\n", version)
		os.Exit(0)
	}

	// Handle search command
	if os.Args[1] == "search" {
		if len(os.Args) < 3 {
			fmt.Println("Usage: ask search <query>")
			os.Exit(1)
		}
		searchUsers(os.Args[2])
		os.Exit(0)
	}

	username := os.Args[1]
	
	if err := validateUsername(username); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}

	// Get user info for confirmation
	userInfo, err := getUserInfo(username)
	if err != nil {
		fmt.Printf("Error fetching user info: %v\n", err)
		os.Exit(1)
	}

	// Ask for confirmation
	if !confirmAddKeys(userInfo) {
		fmt.Println("Operation cancelled.")
		os.Exit(0)
	}

	keys, err := fetchSSHKeys(username)
	if err != nil {
		fmt.Printf("Error fetching SSH keys: %v\n", err)
		os.Exit(1)
	}

	if len(keys) == 0 {
		fmt.Printf("No SSH keys found for user '%s'\n", username)
		os.Exit(1)
	}

	fmt.Printf("Found %d SSH key(s) for user '%s':\n", len(keys), username)
	for i, key := range keys {
		fmt.Printf("  %d. %s\n", i+1, truncateKey(key))
	}

	if err := ensureSSHDirectory(); err != nil {
		fmt.Printf("Error setting up SSH directory: %v\n", err)
		os.Exit(1)
	}

	addedKeys, err := addSSHKeys(keys)
	if err != nil {
		fmt.Printf("Error adding SSH keys: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("\nSuccessfully added %d new SSH key(s) to ~/.ssh/authorized_keys\n", addedKeys)
}

func validateUsername(username string) error {
	if len(username) == 0 {
		return fmt.Errorf("username cannot be empty")
	}
	
	// GitHub username validation: 1-39 characters, alphanumeric and hyphens, no consecutive hyphens
	matched, err := regexp.MatchString(`^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$`, username)
	if err != nil {
		return fmt.Errorf("regex validation failed: %v", err)
	}
	
	if !matched || len(username) > 39 {
		return fmt.Errorf("invalid GitHub username format")
	}
	
	if strings.Contains(username, "--") {
		return fmt.Errorf("username cannot contain consecutive hyphens")
	}
	
	return nil
}

func fetchSSHKeys(username string) ([]string, error) {
	url := fmt.Sprintf("https://github.com/%s.keys", username)
	
	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch keys: %v", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 404 {
		return nil, fmt.Errorf("GitHub user '%s' not found", username)
	}
	
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %v", err)
	}
	
	content := strings.TrimSpace(string(body))
	if content == "" {
		return []string{}, nil
	}
	
	keys := strings.Split(content, "\n")
	var validKeys []string
	
	for _, key := range keys {
		key = strings.TrimSpace(key)
		if key != "" && isValidSSHKey(key) {
			validKeys = append(validKeys, key)
		}
	}
	
	return validKeys, nil
}

func isValidSSHKey(key string) bool {
	// Basic SSH key validation
	parts := strings.Fields(key)
	if len(parts) < 2 {
		return false
	}
	
	keyType := parts[0]
	validTypes := []string{"ssh-rsa", "ssh-dss", "ssh-ed25519", "ecdsa-sha2-nistp256", "ecdsa-sha2-nistp384", "ecdsa-sha2-nistp521"}
	
	for _, validType := range validTypes {
		if keyType == validType {
			return true
		}
	}
	
	return false
}

func ensureSSHDirectory() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get user home directory: %v", err)
	}
	
	sshDir := filepath.Join(homeDir, ".ssh")
	
	// Create .ssh directory if it doesn't exist
	if _, err := os.Stat(sshDir); os.IsNotExist(err) {
		if err := os.MkdirAll(sshDir, 0700); err != nil {
			return fmt.Errorf("failed to create .ssh directory: %v", err)
		}
	}
	
	// Ensure correct permissions for .ssh directory
	if err := os.Chmod(sshDir, 0700); err != nil {
		return fmt.Errorf("failed to set permissions on .ssh directory: %v", err)
	}
	
	// Create authorized_keys file if it doesn't exist
	authorizedKeysPath := filepath.Join(sshDir, "authorized_keys")
	if _, err := os.Stat(authorizedKeysPath); os.IsNotExist(err) {
		file, err := os.Create(authorizedKeysPath)
		if err != nil {
			return fmt.Errorf("failed to create authorized_keys file: %v", err)
		}
		file.Close()
	}
	
	// Ensure correct permissions for authorized_keys file
	if err := os.Chmod(authorizedKeysPath, 0600); err != nil {
		return fmt.Errorf("failed to set permissions on authorized_keys file: %v", err)
	}
	
	return nil
}

func addSSHKeys(keys []string) (int, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return 0, fmt.Errorf("failed to get user home directory: %v", err)
	}
	
	authorizedKeysPath := filepath.Join(homeDir, ".ssh", "authorized_keys")
	
	// Read existing keys
	existingKeys, err := readExistingKeys(authorizedKeysPath)
	if err != nil {
		return 0, fmt.Errorf("failed to read existing keys: %v", err)
	}
	
	// Open file for appending
	file, err := os.OpenFile(authorizedKeysPath, os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		return 0, fmt.Errorf("failed to open authorized_keys file: %v", err)
	}
	defer file.Close()
	
	addedCount := 0
	
	for _, key := range keys {
		if !keyExists(key, existingKeys) {
			if _, err := file.WriteString(key + "\n"); err != nil {
				return addedCount, fmt.Errorf("failed to write key to file: %v", err)
			}
			addedCount++
		}
	}
	
	return addedCount, nil
}

func readExistingKeys(path string) ([]string, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	
	var keys []string
	scanner := bufio.NewScanner(file)
	
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && !strings.HasPrefix(line, "#") {
			keys = append(keys, line)
		}
	}
	
	return keys, scanner.Err()
}

func keyExists(newKey string, existingKeys []string) bool {
	for _, existingKey := range existingKeys {
		if existingKey == newKey {
			return true
		}
	}
	return false
}

func truncateKey(key string) string {
	if len(key) > 80 {
		return key[:77] + "..."
	}
	return key
}

type GitHubUser struct {
	Login     string `json:"login"`
	Name      string `json:"name"`
	Bio       string `json:"bio"`
	Company   string `json:"company"`
	Location  string `json:"location"`
	Email     string `json:"email"`
	PublicRepos int  `json:"public_repos"`
}

type SearchResult struct {
	Items []GitHubUser `json:"items"`
	TotalCount int      `json:"total_count"`
}

func searchUsers(query string) {
	fmt.Printf("Searching for users matching '%s'...\n\n", query)
	
	url := fmt.Sprintf("https://api.github.com/search/users?q=%s&per_page=10", query)
	
	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	
	resp, err := client.Get(url)
	if err != nil {
		fmt.Printf("Error searching users: %v\n", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != 200 {
		fmt.Printf("GitHub API returned status %d\n", resp.StatusCode)
		return
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		fmt.Printf("Error reading response: %v\n", err)
		return
	}
	
	var searchResult SearchResult
	if err := json.Unmarshal(body, &searchResult); err != nil {
		fmt.Printf("Error parsing response: %v\n", err)
		return
	}
	
	if searchResult.TotalCount == 0 {
		fmt.Println("No users found matching your query.")
		return
	}
	
	fmt.Printf("Found %d users:\n", len(searchResult.Items))
	for _, user := range searchResult.Items {
		displayName := user.Name
		if displayName == "" {
			displayName = user.Login
		}
		
		fmt.Printf("  %s - %s", user.Login, displayName)
		
		if user.Bio != "" {
			fmt.Printf(" (%s)", user.Bio)
		}
		
		if user.Company != "" {
			fmt.Printf(" [%s]", user.Company)
		}
		
		fmt.Println()
	}
	
	fmt.Printf("\nUse 'ask <username>' to add SSH keys from any of these users.\n")
}

func getUserInfo(username string) (*GitHubUser, error) {
	url := fmt.Sprintf("https://api.github.com/users/%s", username)
	
	client := &http.Client{
		Timeout: 10 * time.Second,
	}
	
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch user info: %v", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode == 404 {
		return nil, fmt.Errorf("GitHub user '%s' not found", username)
	}
	
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("GitHub API returned status %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %v", err)
	}
	
	var user GitHubUser
	if err := json.Unmarshal(body, &user); err != nil {
		return nil, fmt.Errorf("failed to parse user info: %v", err)
	}
	
	return &user, nil
}

func confirmAddKeys(user *GitHubUser) bool {
	displayName := user.Name
	if displayName == "" {
		displayName = user.Login
	}
	
	fmt.Printf("User: %s (%s)\n", user.Login, displayName)
	
	if user.Bio != "" {
		fmt.Printf("Bio: %s\n", user.Bio)
	}
	
	if user.Company != "" {
		fmt.Printf("Company: %s\n", user.Company)
	}
	
	if user.Location != "" {
		fmt.Printf("Location: %s\n", user.Location)
	}
	
	fmt.Printf("Public repos: %d\n", user.PublicRepos)
	
	fmt.Printf("\nAre you sure you want to add %s's SSH keys? (y/N): ", displayName)
	
	var response string
	fmt.Scanln(&response)
	
	response = strings.ToLower(strings.TrimSpace(response))
	return response == "y" || response == "yes"
}