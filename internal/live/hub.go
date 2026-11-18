// Package live owns live scoring: score events, court snapshots, and the
// broadcast hub that pushes snapshots to TV screens, event pages, and panels.
//
// The hub is transport-agnostic: the WebSocket handler (T-033) subscribes on
// behalf of each connection and writes received messages to the socket.
// See docs/ARCHITECTURE.md §6.
package live

import (
	"sync"
	"sync/atomic"
)

// Message is one broadcast payload (already-encoded JSON) for a topic such as "court:{id}".
type Message struct {
	Topic string
	V     int64  // monotonically increasing version per topic
	Data  []byte // JSON
}

// Subscription receives messages for the topics it was created with.
// C is closed when the subscription is cancelled or dropped for being slow.
type Subscription struct {
	C       <-chan Message
	ch      chan Message
	topics  []string
	hub     *Hub
	once    sync.Once
	dropped atomic.Bool
}

// Dropped reports whether the hub closed this subscription because its buffer was full.
func (s *Subscription) Dropped() bool { return s.dropped.Load() }

// Cancel removes the subscription from the hub and closes C. Safe to call more than once.
func (s *Subscription) Cancel() { s.hub.remove(s, false) }

// Hub fans out messages to subscribers in memory. It keeps the last message per
// topic so new subscribers immediately receive the current snapshot.
type Hub struct {
	mu     sync.RWMutex
	subs   map[string]map[*Subscription]struct{}
	last   map[string]Message
	buffer int

	published atomic.Int64
	drops     atomic.Int64
}

// NewHub creates a hub; buffer is the per-subscriber queue length (min 1).
func NewHub(buffer int) *Hub {
	if buffer < 1 {
		buffer = 1
	}
	return &Hub{
		subs:   make(map[string]map[*Subscription]struct{}),
		last:   make(map[string]Message),
		buffer: buffer,
	}
}

// Subscribe registers for topics. The latest known message of each topic is
// delivered first (as long as it fits in the buffer).
func (h *Hub) Subscribe(topics ...string) *Subscription {
	ch := make(chan Message, h.buffer)
	s := &Subscription{C: ch, ch: ch, topics: append([]string(nil), topics...), hub: h}
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, t := range s.topics {
		if h.subs[t] == nil {
			h.subs[t] = make(map[*Subscription]struct{})
		}
		h.subs[t][s] = struct{}{}
		if m, ok := h.last[t]; ok {
			select {
			case ch <- m:
			default:
			}
		}
	}
	return s
}

// Publish stores m as the latest message for its topic and delivers it to all
// subscribers without blocking. Messages with a version lower than the stored
// one are ignored. Subscribers whose buffer is full are dropped; they are
// expected to reconnect and receive the latest snapshot.
func (h *Hub) Publish(m Message) {
	h.mu.Lock()
	if prev, ok := h.last[m.Topic]; ok && m.V < prev.V {
		h.mu.Unlock()
		return
	}
	h.last[m.Topic] = m
	var slow []*Subscription
	for s := range h.subs[m.Topic] {
		select {
		case s.ch <- m:
		default:
			slow = append(slow, s)
		}
	}
	h.mu.Unlock()
	h.published.Add(1)
	for _, s := range slow {
		h.remove(s, true)
	}
}

func (h *Hub) remove(s *Subscription, dropped bool) {
	s.once.Do(func() {
		if dropped {
			s.dropped.Store(true)
			h.drops.Add(1)
		}
		h.mu.Lock()
		for _, t := range s.topics {
			delete(h.subs[t], s)
			if len(h.subs[t]) == 0 {
				delete(h.subs, t)
			}
		}
		h.mu.Unlock()
		close(s.ch)
	})
}

// Stats is a point-in-time view used by /metrics.
type Stats struct {
	Topics      int
	Subscribers int
	Published   int64
	Dropped     int64
}

// Stats returns counters for monitoring.
func (h *Hub) Stats() Stats {
	h.mu.RLock()
	defer h.mu.RUnlock()
	seen := make(map[*Subscription]struct{})
	for _, m := range h.subs {
		for s := range m {
			seen[s] = struct{}{}
		}
	}
	return Stats{Topics: len(h.subs), Subscribers: len(seen), Published: h.published.Load(), Dropped: h.drops.Load()}
}
