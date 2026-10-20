import Foundation

// Entry point of the Linux engine build: the same headless harnesses as the app (see Engine/HarnessCLI.swift).
if let code = HarnessCLI.run(CommandLine.arguments) { exit(code) }
print("usage: tt --check-save <file> | --calendar-check | --forecast-check | --determinism | --scenarios [A,B,…|all]")
print("          --playtest <era> <seeds> [years] [table|full|quiet] [flags] | --research|--industry|--watch|--strategy|--experience|--ventures|--simulate <era> | --scale")
exit(64)
