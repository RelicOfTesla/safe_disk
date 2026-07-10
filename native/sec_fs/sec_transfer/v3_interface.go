package sec_transfer

import (
	"context"
	"errors"
	"sync"
	"time"

	"safe_disk/native/sec_fs"
)

// V3Transfer is the simplified transfer API. It deliberately avoids the v2
// task/progress persistence model: import/export have runtime progress and
// operation markers only; convert has phase markers because it is destructive.
type V3Transfer interface {
	ImportFile(ctx context.Context, req ImportFileRequest, cb V3ProgressCallback) error
	ImportDirectory(ctx context.Context, req ImportDirectoryRequest, cb V3ProgressCallback) error
	ExportFile(ctx context.Context, req ExportFileRequest, cb V3ProgressCallback) error
	ExportDirectory(ctx context.Context, req ExportDirectoryRequest, cb V3ProgressCallback) error

	ConvertRoot(ctx context.Context, req ConvertRequest, cb V3ProgressCallback) error
	RecoverConvert(ctx context.Context, rootPath string) (RecoverResult, error)

	ListUnfinishedOperations(ctx context.Context, rootPath string) ([]OperationMarker, error)
	CleanUnfinishedImportExport(ctx context.Context, rootPath string, opID string) error
}

type ImportFileRequest struct {
	Source    sec_fs.FullStorePath
	DestRoot  sec_fs.ISecRoot
	Dest      sec_fs.RelativeViewPath
	Overwrite bool
}

type ImportDirectoryRequest struct {
	Source        sec_fs.FullStorePath
	DestRoot      sec_fs.ISecRoot
	Dest          sec_fs.RelativeViewPath
	SkipRecursive bool
	Overwrite     bool
}

type ExportFileRequest struct {
	SourceRoot sec_fs.ISecRoot
	Source     sec_fs.RelativeViewPath
	Dest       sec_fs.FullStorePath
	Overwrite  bool
}

type ExportDirectoryRequest struct {
	SourceRoot    sec_fs.ISecRoot
	Source        sec_fs.RelativeViewPath
	Dest          sec_fs.FullStorePath
	SkipRecursive bool
	Overwrite     bool
}

type ConvertKind string

const (
	ConvertKindEncrypt ConvertKind = "convert_encrypt"
	ConvertKindDecrypt ConvertKind = "convert_decrypt"
)

type ConvertRequest struct {
	Kind      ConvertKind
	RootPath  string
	Password  string
	Overwrite bool
}

type OperationType string

const (
	OperationImport         OperationType = "import"
	OperationExport         OperationType = "export"
	OperationConvertEncrypt OperationType = "convert_encrypt"
	OperationConvertDecrypt OperationType = "convert_decrypt"
)

type OperationMarker struct {
	Version   int           `json:"version"`
	OpID      string        `json:"op_id"`
	Type      OperationType `json:"type"`
	Status    string        `json:"status"`
	Phase     string        `json:"phase,omitempty"`
	Src       string        `json:"src,omitempty"`
	Dst       string        `json:"dst,omitempty"`
	Root      string        `json:"root,omitempty"`
	Work      string        `json:"work,omitempty"`
	Backup    string        `json:"backup,omitempty"`
	CreatedAt time.Time     `json:"created_at"`
	UpdatedAt time.Time     `json:"updated_at"`
}

type ProgressEvent struct {
	OpID        string
	Type        OperationType
	TotalFiles  int64
	DoneFiles   int64
	CurrentPath string
	Error       error
	Complete    bool
}

type V3ProgressCallback func(progress ProgressEvent)

type RecoverAction string

const (
	RecoverActionNone           RecoverAction = "none"
	RecoverActionRerun          RecoverAction = "rerun"
	RecoverActionContinueRename RecoverAction = "continue_rename"
	RecoverActionNeedsAttention RecoverAction = "needs_attention"
	RecoverActionCompleted      RecoverAction = "completed"
)

type RecoverResult struct {
	Marker       OperationMarker
	Action       RecoverAction
	Message      string
	RootExists   bool
	WorkExists   bool
	BackupExists bool
}

var (
	ErrTransferV3NotRegistered = errors.New("transfer v3 implementation is not registered")
	transferV3FactoryMu        sync.RWMutex
	transferV3Factory          func() V3Transfer
)

// RegisterTransferV3Factory installs the process-wide V3 implementation.
// CLI and FFI register sec_transfer/v3 from their main packages.
func RegisterTransferV3Factory(factory func() V3Transfer) {
	transferV3FactoryMu.Lock()
	transferV3Factory = factory
	transferV3FactoryMu.Unlock()
}

// GetDefaultTransferV3 returns an unavailable implementation when registration
// was omitted. Operations then return ErrTransferV3NotRegistered instead of
// crashing the process at a public API boundary.
func GetDefaultTransferV3() V3Transfer {
	transferV3FactoryMu.RLock()
	factory := transferV3Factory
	transferV3FactoryMu.RUnlock()
	if factory == nil {
		return unavailableV3Transfer{}
	}
	manager := factory()
	if manager == nil {
		return unavailableV3Transfer{}
	}
	return manager
}

type unavailableV3Transfer struct{}

func (unavailableV3Transfer) ImportFile(context.Context, ImportFileRequest, V3ProgressCallback) error {
	return ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) ImportDirectory(context.Context, ImportDirectoryRequest, V3ProgressCallback) error {
	return ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) ExportFile(context.Context, ExportFileRequest, V3ProgressCallback) error {
	return ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) ExportDirectory(context.Context, ExportDirectoryRequest, V3ProgressCallback) error {
	return ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) ConvertRoot(context.Context, ConvertRequest, V3ProgressCallback) error {
	return ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) RecoverConvert(context.Context, string) (RecoverResult, error) {
	return RecoverResult{}, ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) ListUnfinishedOperations(context.Context, string) ([]OperationMarker, error) {
	return nil, ErrTransferV3NotRegistered
}

func (unavailableV3Transfer) CleanUnfinishedImportExport(context.Context, string, string) error {
	return ErrTransferV3NotRegistered
}
