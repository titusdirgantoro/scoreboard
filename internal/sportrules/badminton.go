// Package sportrules implements scoring rules per sport. It must behave exactly
// like packages/sportrules (TypeScript); both are tested against the shared
// fixtures in testdata/sportrules (see ADR-0004).
package sportrules

import (
	"fmt"
	"strconv"
	"strings"
)

// Side identifies a team/player slot in a match.
type Side string

// Match sides.
const (
	A Side = "A"
	B Side = "B"
)

// Score is a pair of counters.
type Score struct {
	A int `json:"a"`
	B int `json:"b"`
}

func (s *Score) add(side Side) {
	if side == A {
		s.A++
	} else {
		s.B++
	}
}

// BadmintonFormat describes a rally-point badminton format.
type BadmintonFormat struct {
	Target int `json:"target"` // points to win a game (21 or 15)
	Cap    int `json:"cap"`    // score that wins outright (30 or 21)
	BestOf int `json:"bestOf"` // games in a match (3)
}

// Standard BWF formats. 3×15 applies from 4 January 2027.
var (
	Badminton3x21 = BadmintonFormat{Target: 21, Cap: 30, BestOf: 3}
	Badminton3x15 = BadmintonFormat{Target: 15, Cap: 21, BestOf: 3}
)

// BadmintonState is an immutable-by-convention match state. Use Rally to advance.
type BadmintonState struct {
	Format   BadmintonFormat `json:"format"`
	Games    [][2]int        `json:"games"` // finished games as [a, b]
	GamesWon Score           `json:"gamesWon"`
	Current  Score           `json:"current"`
	Server   Side            `json:"server"`
	Finished bool            `json:"finished"`
	Winner   Side            `json:"winner"` // "" while unfinished
}

// NewBadminton starts a match.
func NewBadminton(f BadmintonFormat, firstServer Side) BadmintonState {
	return BadmintonState{Format: f, Games: [][2]int{}, Server: firstServer}
}

func gameWon(f BadmintonFormat, own, other int) bool {
	return own >= f.Target && (own-other >= 2 || own >= f.Cap)
}

// Rally returns the state after winner wins one rally. The rally winner serves
// next (rally-point scoring); the game winner serves first in the next game.
// Rallies after the match is finished are ignored.
func (s BadmintonState) Rally(winner Side) BadmintonState {
	if s.Finished {
		return s
	}
	next := s
	next.Games = append(make([][2]int, 0, len(s.Games)+1), s.Games...)
	next.Current.add(winner)
	next.Server = winner

	own, other := next.Current.A, next.Current.B
	if winner == B {
		own, other = other, own
	}
	if !gameWon(s.Format, own, other) {
		return next
	}
	next.Games = append(next.Games, [2]int{next.Current.A, next.Current.B})
	next.GamesWon.add(winner)
	next.Current = Score{}
	need := s.Format.BestOf/2 + 1
	if next.GamesWon.A >= need || next.GamesWon.B >= need {
		next.Finished = true
		next.Winner = winner
	}
	return next
}

// ReplayBadminton rebuilds a state from the rally log.
func ReplayBadminton(f BadmintonFormat, firstServer Side, rallies []Side) BadmintonState {
	s := NewBadminton(f, firstServer)
	for _, r := range rallies {
		s = s.Rally(r)
	}
	return s
}

// ParseRallies parses the fixture notation "A20 B20 A1" into a rally list.
func ParseRallies(notation string) ([]Side, error) {
	var out []Side
	for _, tok := range strings.Fields(notation) {
		side := Side(strings.ToUpper(tok[:1]))
		if side != A && side != B {
			return nil, fmt.Errorf("token %q: sisi harus A atau B", tok)
		}
		n := 1
		if len(tok) > 1 {
			v, err := strconv.Atoi(tok[1:])
			if err != nil || v < 1 {
				return nil, fmt.Errorf("token %q: jumlah reli tidak valid", tok)
			}
			n = v
		}
		for i := 0; i < n; i++ {
			out = append(out, side)
		}
	}
	return out, nil
}
