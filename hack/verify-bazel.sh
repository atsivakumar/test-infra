#!/usr/bin/env bash
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

TESTINFRA_ROOT=$(git rev-parse --show-toplevel)
TMP_GOPATH=$(mktemp -d)

"${TESTINFRA_ROOT}/hack/go_install_from_commit.sh" \
  github.com/kubernetes/repo-infra/kazel \
  2a736b4fba317cf3038e3cbd06899b544b875fae \
  "${TMP_GOPATH}"

"${TESTINFRA_ROOT}/hack/go_install_from_commit.sh" \
  github.com/bazelbuild/bazel-gazelle/cmd/gazelle \
  eaa1e87d2a3ca716780ca6650ef5b9b9663b8773 \
  "${TMP_GOPATH}"

touch "${TESTINFRA_ROOT}/vendor/BUILD"

gazelle_diff=$("${TMP_GOPATH}/bin/gazelle" fix \
  -build_file_name=BUILD,BUILD.bazel \
  -external=vendored \
  -mode=diff \
  -repo_root="${TESTINFRA_ROOT}")

kazel_diff=$("${TMP_GOPATH}/bin/kazel" \
  -dry-run \
  -print-diff \
  -root="${TESTINFRA_ROOT}")

# check if there are vendor/*_test.go
# previously we used godeps which did this, but `dep` does not handle this
# properly yet. some of these tests don't build well. see:
# ref: https://github.com/kubernetes/test-infra/pull/5411
vendor_tests=$(find ${TESTINFRA_ROOT}/vendor/ -name "*_test.go" | wc -l)

if [[ -n "${gazelle_diff}" || -n "${kazel_diff}" || "${vendor_tests}" -ne "0" ]]; then
  echo "${gazelle_diff}"
  echo "${kazel_diff}"
  echo "number of vendor/*_test.go: ${vendor_tests} (want: 0)"
  echo
  echo "Run ./hack/update-bazel.sh"
  exit 1
fi
