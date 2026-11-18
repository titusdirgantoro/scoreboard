package sportrules

import (
	"encoding/json"
	"os"
	"reflect"
	"testing"
)

type badmintonFixture struct {
	Formats map[string]BadmintonFormat `json:"formats"`
	Cases   []struct {
		Name        string `json:"name"`
		Format      string `json:"format"`
		FirstServer Side   `json:"firstServer"`
		Rallies     string `json:"rallies"`
		Expect      struct {
			Games    [][2]int `json:"games"`
			GamesWon Score    `json:"gamesWon"`
			Current  Score    `json:"current"`
			Server   Side     `json:"server"`
			Finished bool     `json:"finished"`
			Winner   Side     `json:"winner"`
		} `json:"expect"`
	} `json:"cases"`
}

func TestBadmintonSharedFixtures(t *testing.T) {
	raw, err := os.ReadFile("../../testdata/sportrules/badminton.json")
	if err != nil {
		t.Fatal(err)
	}
	var fx badmintonFixture
	if err := json.Unmarshal(raw, &fx); err != nil {
		t.Fatal(err)
	}
	if len(fx.Cases) == 0 {
		t.Fatal("fixture kosong")
	}
	for _, c := range fx.Cases {
		t.Run(c.Name, func(t *testing.T) {
			f, ok := fx.Formats[c.Format]
			if !ok {
				t.Fatalf("format %q tidak ada", c.Format)
			}
			rallies, err := ParseRallies(c.Rallies)
			if err != nil {
				t.Fatal(err)
			}
			got := ReplayBadminton(f, c.FirstServer, rallies)
			e := c.Expect
			if !reflect.DeepEqual(got.Games, e.Games) || got.GamesWon != e.GamesWon || got.Current != e.Current ||
				got.Server != e.Server || got.Finished != e.Finished || got.Winner != e.Winner {
				t.Fatalf("hasil tidak sama\n dapat: games=%v won=%+v cur=%+v server=%s finished=%v winner=%q\n mau:   games=%v won=%+v cur=%+v server=%s finished=%v winner=%q",
					got.Games, got.GamesWon, got.Current, got.Server, got.Finished, got.Winner,
					e.Games, e.GamesWon, e.Current, e.Server, e.Finished, e.Winner)
			}
		})
	}
}

func TestStandardFormatsMatchFixture(t *testing.T) {
	raw, err := os.ReadFile("../../testdata/sportrules/badminton.json")
	if err != nil {
		t.Fatal(err)
	}
	var fx badmintonFixture
	if err := json.Unmarshal(raw, &fx); err != nil {
		t.Fatal(err)
	}
	if fx.Formats["3x21"] != Badminton3x21 || fx.Formats["3x15"] != Badminton3x15 {
		t.Fatalf("format standar berbeda dari fixture: %+v", fx.Formats)
	}
}

func TestRallyDoesNotMutateInput(t *testing.T) {
	s := NewBadminton(Badminton3x21, A)
	for i := 0; i < 21; i++ {
		s = s.Rally(A)
	}
	before := len(s.Games)
	_ = s.Rally(B)
	if len(s.Games) != before || s.Current != (Score{}) {
		t.Fatal("Rally mengubah state asal")
	}
}

func TestParseRalliesRejectsBadTokens(t *testing.T) {
	for _, bad := range []string{"C1", "A0", "Ax"} {
		if _, err := ParseRallies(bad); err == nil {
			t.Fatalf("%q seharusnya ditolak", bad)
		}
	}
}
