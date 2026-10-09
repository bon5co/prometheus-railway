// bcrypt-hash prints the bcrypt hash of the password in $PROMETHEUS_PASSWORD.
// Prometheus's web.config.file accepts only bcrypt hashes, and the upstream
// image ships neither htpasswd nor openssl to make one.
package main

import (
	"fmt"
	"os"

	"golang.org/x/crypto/bcrypt"
)

func main() {
	pw := os.Getenv("PROMETHEUS_PASSWORD")
	if pw == "" {
		fmt.Fprintln(os.Stderr, "PROMETHEUS_PASSWORD is empty")
		os.Exit(1)
	}
	if len(pw) > 72 {
		fmt.Fprintln(os.Stderr, "PROMETHEUS_PASSWORD longer than 72 bytes; bcrypt would truncate it")
		os.Exit(1)
	}
	h, err := bcrypt.GenerateFromPassword([]byte(pw), 10)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Print(string(h))
}
