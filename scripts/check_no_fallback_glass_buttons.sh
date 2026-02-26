#!/usr/bin/env bash
set -euo pipefail

runtime_files=(
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Views/UpdatesView.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Views/ImportView.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Views/SettingsView.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Components/EnvironmentListDisplay.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Components/QueuePanelComponents.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Components/DownloadQueueRowComponents.swift"
  "/Users/pete/GitHub_EUC/juice_swift/Juice/Components/StyleHelpers.swift"
)

status=0

for file in "${runtime_files[@]}"; do
  awk -v file="$file" '
    { lines[NR] = $0 }
    /buttonStyle\(\.glass/ {
      guarded = 0
      for (i = NR; i >= NR - 120 && i >= 1; i--) {
        if (lines[i] ~ /#available\(macOS 26/ || lines[i] ~ /@available\(macOS 26/) {
          guarded = 1
          break
        }
      }
      if (!guarded) {
        printf "%s:%d: unguarded glass button style in runtime file: %s\n", file, NR, $0
        violation = 1
      }
    }
    END {
      if (violation == 1) {
        exit 1
      }
    }
  ' "$file" || status=1

done

if [[ $status -eq 0 ]]; then
  echo "No unguarded .buttonStyle(.glass...) usages detected in runtime fallback-audited files."
fi

exit $status
