package live

import (
	"sync"
	"testing"
	"time"
)

func recv(t *testing.T, s *Subscription) Message {
	t.Helper()
	select {
	case m, ok := <-s.C:
		if !ok {
			t.Fatal("channel tertutup")
		}
		return m
	case <-time.After(time.Second):
		t.Fatal("tidak ada pesan dalam 1 detik")
	}
	return Message{}
}

func TestSubscriberGetsLatestSnapshotFirst(t *testing.T) {
	h := NewHub(4)
	h.Publish(Message{Topic: "court:1", V: 1, Data: []byte(`{"a":1}`)})
	h.Publish(Message{Topic: "court:1", V: 2, Data: []byte(`{"a":2}`)})
	s := h.Subscribe("court:1")
	defer s.Cancel()
	if m := recv(t, s); m.V != 2 {
		t.Fatalf("snapshot awal v=%d, mau 2", m.V)
	}
}

func TestPublishFansOutAndIgnoresOldVersions(t *testing.T) {
	h := NewHub(4)
	a := h.Subscribe("court:1")
	b := h.Subscribe("court:1", "event:9")
	defer a.Cancel()
	defer b.Cancel()

	h.Publish(Message{Topic: "court:1", V: 5})
	h.Publish(Message{Topic: "court:1", V: 4}) // lebih lama → diabaikan
	h.Publish(Message{Topic: "event:9", V: 1})

	if m := recv(t, a); m.V != 5 {
		t.Fatalf("a v=%d", m.V)
	}
	if m := recv(t, b); m.Topic != "court:1" || m.V != 5 {
		t.Fatalf("b pertama %+v", m)
	}
	if m := recv(t, b); m.Topic != "event:9" {
		t.Fatalf("b kedua %+v", m)
	}
	select {
	case m := <-a.C:
		t.Fatalf("a tidak boleh menerima versi lama: %+v", m)
	default:
	}
}

func TestSlowSubscriberIsDropped(t *testing.T) {
	h := NewHub(1)
	slow := h.Subscribe("court:1")
	h.Publish(Message{Topic: "court:1", V: 1})
	h.Publish(Message{Topic: "court:1", V: 2}) // buffer penuh → diputus
	if !slow.Dropped() {
		t.Fatal("subscriber lambat seharusnya diputus")
	}
	if st := h.Stats(); st.Subscribers != 0 || st.Dropped != 1 {
		t.Fatalf("stats %+v", st)
	}
	// channel harus tertutup setelah pesan yang tersisa dibaca
	<-slow.C
	if _, ok := <-slow.C; ok {
		t.Fatal("channel seharusnya tertutup")
	}
}

func TestConcurrentPublishSubscribe(t *testing.T) {
	h := NewHub(64)
	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			s := h.Subscribe("court:1")
			time.Sleep(time.Millisecond)
			s.Cancel()
			s.Cancel() // aman dipanggil dua kali
		}()
	}
	for v := int64(1); v <= 200; v++ {
		h.Publish(Message{Topic: "court:1", V: v})
	}
	wg.Wait()
	if st := h.Stats(); st.Subscribers != 0 {
		t.Fatalf("masih ada subscriber: %+v", st)
	}
}
