package main

import (
	"context"
	"encoding/json"
	"testing"
	"time"
)

func TestWebDavOperationStoreCancellationIsObservable(t *testing.T) {
	store := newWebDavOperationStore()
	start := store.start("mount-1", func(ctx context.Context) string {
		<-ctx.Done()
		return SuccessWithData(map[string]bool{"mounted": false})
	})
	if response := assertJSONSuccess(t, start); response["data"].(map[string]interface{})["state"] != "running" {
		t.Fatalf("start response = %s", start)
	}

	if active := store.cancel("mount-1"); !active {
		t.Fatal("cancel did not report an active operation")
	}
	deadline := time.Now().Add(time.Second)
	for {
		response := assertJSONSuccess(t, store.poll("mount-1"))
		data := response["data"].(map[string]interface{})
		if data["state"] == "cancelled" {
			if _, ok := data["response"].(map[string]interface{}); !ok {
				t.Fatal("cancelled operation did not preserve nested response")
			}
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("operation did not finish cancellation: %s", store.poll("mount-1"))
		}
		time.Sleep(time.Millisecond)
	}

	if active := store.cancel("mount-1"); active {
		t.Fatal("completed operation remained cancellable")
	}
	if response := store.poll("mount-1"); jsonSuccess(response) {
		t.Fatal("consumed operation remained pollable")
	}
}

func TestWebDavOperationStoreRejectsDuplicateIDs(t *testing.T) {
	store := newWebDavOperationStore()
	store.start("same", func(context.Context) string {
		time.Sleep(20 * time.Millisecond)
		return Success()
	})
	if response := store.start("same", func(context.Context) string { return Success() }); jsonSuccess(response) {
		t.Fatal("duplicate operation ID unexpectedly succeeded")
	}
}

func assertJSONSuccess(t *testing.T, raw string) map[string]interface{} {
	t.Helper()
	var response map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &response); err != nil {
		t.Fatalf("invalid JSON response %q: %v", raw, err)
	}
	if response["success"] != true {
		t.Fatalf("response failed: %s", raw)
	}
	return response
}
