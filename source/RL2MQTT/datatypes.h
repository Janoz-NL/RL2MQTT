#pragma once

// The structure of a ticker stat event
struct StatTickerParams {
	// person who got a stat
	uintptr_t Receiver;
	// person who is victim of a stat (only exists for demos afaik)
	uintptr_t Victim;
	// wrapper for the stat event
	uintptr_t StatEvent;
};

// structure of a stat event
struct StatEventParams {
	// always primary player
	uintptr_t PRI;
	// wrapper for the stat event
	uintptr_t StatEvent;
};