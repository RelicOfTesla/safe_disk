//go:build windows

package sec_transfer_v3

// Windows requires platform-specific directory handles for metadata flushing.
// File data is still synced; directory metadata durability remains best effort.
func syncDirectory(string) error {
	return nil
}
