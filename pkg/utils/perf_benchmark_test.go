/*
Copyright © contributors to CloudNativePG, established as
CloudNativePG a Series of LF Projects, LLC.
Licensed under the Apache License, Version 2.0. SPDX-License-Identifier: Apache-2.0
*/

package utils

import (
	"encoding/json"
	"fmt"
	"testing"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Benchmarks for pure hot paths in pkg/utils. Deterministic fixed inputs.
// Run: go test ./pkg/utils/ -run '^$' -bench 'BenchmarkPerf' -benchtime=1000x -count=1

func BenchmarkPerfParsePgControldataOutput(b *testing.B) {
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_ = ParsePgControldataOutput(fakeControlData)
	}
}

func BenchmarkPerfGetFencedInstances(b *testing.B) {
	names := make([]string, 0, 20)
	for i := 0; i < 20; i++ {
		names = append(names, fmt.Sprintf("cluster-1-%d", i))
	}
	raw, err := json.Marshal(names)
	if err != nil {
		b.Fatal(err)
	}
	annotations := map[string]string{FencedInstanceAnnotation: string(raw)}
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		_, _ = GetFencedInstances(annotations)
	}
}

func BenchmarkPerfInheritLabels(b *testing.B) {
	labels := map[string]string{}
	fixed := map[string]string{}
	inherited := make([]string, 0, 20)
	for i := 0; i < 20; i++ {
		key := fmt.Sprintf("label-%d", i)
		labels[key] = "value"
		inherited = append(inherited, key)
		fixed[fmt.Sprintf("fixed-%d", i)] = "value"
	}
	ctrl := &fakeInhericanceController{labels: inherited}
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		obj := &metav1.ObjectMeta{}
		InheritLabels(obj, labels, fixed, ctrl)
	}
}
