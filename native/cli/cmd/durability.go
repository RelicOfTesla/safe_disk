package cmd

import (
	"fmt"

	"safe_disk/native/sec_fs/sec_transfer"
)

const durabilityFlagUsage = "Durability policy: none, data, full"

func parseDurability(value string) (sec_transfer.DurabilityLevel, error) {
	level := sec_transfer.DurabilityLevel(value)
	switch level {
	case sec_transfer.DurabilityNone, sec_transfer.DurabilityData, sec_transfer.DurabilityFull:
		return level, nil
	default:
		return "", fmt.Errorf("invalid --durability value %q; expected none, data, or full", value)
	}
}
