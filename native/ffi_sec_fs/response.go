// Package ffi_sec_fs provides FFI adapter layer for sec_fs.
// This file contains response utilities for FFI communication.
package main

import "encoding/json"

const (
	ErrorCodeInvalidPassword        = 1001
	ErrorCodePasswordVerifierAbsent = 1002
	ErrorCodeInvalidConfig          = 1101
)

// Response represents a standard FFI response structure.
type Response struct {
	Success bool        `json:"success"`
	Error   string      `json:"error,omitempty"`
	Data    interface{} `json:"data,omitempty"`
	Code    int         `json:"code,omitempty"`
}

// SuccessWithData creates a JSON response string indicating success with data.
func SuccessWithData(data interface{}) string {
	resp := Response{Success: true, Data: data}
	b, _ := json.Marshal(resp)
	return string(b)
}

// Success creates a JSON response string indicating success without data.
func Success() string {
	resp := Response{Success: true}
	b, _ := json.Marshal(resp)
	return string(b)
}

// ErrorResponse creates a JSON response string indicating an error.
func ErrorResponse(error string) string {
	resp := Response{Success: false, Error: error}
	b, _ := json.Marshal(resp)
	return string(b)
}

// ErrorWithCode creates a JSON response string indicating an error with a code.
func ErrorWithCode(error string, code int) string {
	resp := Response{Success: false, Error: error, Code: code}
	b, _ := json.Marshal(resp)
	return string(b)
}

// JsonResult creates a JSON response string from the given data.
func JsonResult(data interface{}) string {
	b, _ := json.Marshal(data)
	return string(b)
}
