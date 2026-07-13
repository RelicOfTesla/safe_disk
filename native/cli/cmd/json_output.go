package cmd

import (
	"encoding/json"
	"fmt"
	"os"

	"safe_disk/native/sec_fs/sec_transfer"
)

type transferJSONReporter struct {
	opType  sec_transfer.OperationType
	started bool
	failed  bool
}

type jsonReportedError struct{ err error }

func (e jsonReportedError) Error() string { return e.err.Error() }
func (e jsonReportedError) Unwrap() error { return e.err }

func newTransferJSONReporter(opType sec_transfer.OperationType) *transferJSONReporter {
	return &transferJSONReporter{opType: opType}
}

func (r *transferJSONReporter) Callback() sec_transfer.V3ProgressCallback {
	return func(progress sec_transfer.ProgressEvent) {
		r.reportProgress(progress)
	}
}

func (r *transferJSONReporter) reportProgress(progress sec_transfer.ProgressEvent) {
	opType := progress.Type
	if opType == "" {
		opType = r.opType
	}
	if !r.started {
		r.started = true
		writeJSONLine(map[string]interface{}{
			"event": "operation_started",
			"op_id": progress.OpID,
			"type":  opType,
		})
	}
	if progress.Error != nil {
		r.failed = true
		writeJSONLine(map[string]interface{}{
			"event": "operation_failed",
			"op_id": progress.OpID,
			"type":  opType,
			"error": progress.Error.Error(),
		})
		return
	}
	if progress.Complete {
		writeJSONLine(map[string]interface{}{
			"event":     "operation_completed",
			"op_id":     progress.OpID,
			"type":      opType,
			"completed": progress.DoneFiles,
			"total":     progress.TotalFiles,
		})
		return
	}
	writeJSONLine(map[string]interface{}{
		"event":        "progress",
		"op_id":        progress.OpID,
		"type":         opType,
		"completed":    progress.DoneFiles,
		"total":        progress.TotalFiles,
		"current_file": progress.CurrentPath,
	})
}

func (r *transferJSONReporter) Failed(err error) {
	if err == nil || r.failed {
		return
	}
	r.failed = true
	writeJSONLine(map[string]interface{}{
		"event": "operation_failed",
		"type":  r.opType,
		"error": err.Error(),
	})
}

func (r *transferJSONReporter) WrapError(err error) error {
	r.Failed(err)
	return jsonReportedError{err: err}
}

func writeJSONLine(event map[string]interface{}) {
	data, err := json.Marshal(event)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to encode json event: %v\n", err)
		return
	}
	fmt.Println(string(data))
}
