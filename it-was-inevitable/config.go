package main

const (
	// Pause DF-AI when the queue length gets above this threshold.
	maxQueuedLines = 1000

	// Unpause DF-AI when the queue length gets below this threshold.
	minQueuedLines = 500

	// Minimum number of lines before a duplicate is allowed.
	minLinesBeforeDuplicate = 500

	// Maximum number of "fuzzy" (some words changed) duplicates allowed.
	maxFuzzyDuplicates = 5

	// Number of lines to remember for "fuzzy" duplicate checking.
	fuzzyDuplicateWindow = 10

	// Maximum number of words that can differ in a "fuzzy" duplicate.
	maxFuzzyDifferentWords = 2
)