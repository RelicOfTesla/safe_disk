package sec_transfer_v3

import "safe_disk/native/sec_fs/sec_transfer"

func init() {
	sec_transfer.GetDefaultTransferV3 = func() sec_transfer.V3Transfer {
		return New()
	}
}
