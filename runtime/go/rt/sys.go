package rt

import (
	"io"
	"os"
)

// Stdout is the capability to write to standard output (CAP-001). Its field is unexported so that
// Égide code cannot forge it (CAP-002); only NewSys creates one.
type Stdout struct{ w io.Writer }

// Write writes p to standard output.
func (s Stdout) Write(p []byte) (int, error) { return s.w.Write(p) }

// Sys is the root capability passed to an Égide program's main (CAP-010). Seed: only standard streams;
// the other capabilities of spec/06 are added in phase 4 (tasks T-0070..T-0072).
type Sys struct {
	Stdout Stdout
	Stderr Stdout
}

// NewSys is called exactly once by the generated main wrapper.
func NewSys() Sys {
	return Sys{Stdout: Stdout{w: os.Stdout}, Stderr: Stdout{w: os.Stderr}}
}
